import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/batch_progress.dart';
import '../models/template_media.dart';
import '../models/text_style_config.dart';
import 'ffmpeg_service.dart';
import 'gallery_service.dart';
import 'overlay_renderer.dart';

/// Motor de renderizado por lotes (imágenes con dart:ui, videos con FFmpeg).
///
/// Garantías:
///  - **Estrictamente secuencial**: cada invitado espera (`await`) a que termine
///    la sesión de FFmpeg, se verifique el código de retorno y el archivo de
///    salida, y se publique en MediaStore antes de pasar al siguiente.
///  - **Temporales únicos** por invitado e intento (`overlay_<i>_<ts>.png`,
///    `temp_out_<i>_<ts>.mp4`): nunca se reutiliza ni se lee un archivo de otra
///    iteración.
///  - **Sin estado compartido**: el texto, su layout, el canvas y las
///    coordenadas se recalculan desde cero en cada iteración.
///  - Los temporales se borran solo cuando ya no hacen falta (después de
///    confirmar el guardado en MediaStore, o al descartar un intento fallido).
class BatchRenderer {
  BatchRenderer({
    this._ffmpeg = const FfmpegService(),
    this._gallery = const GalleryService(),
  });

  /// Intentos por video si el archivo resultante no pasa la validación.
  static const int maxAttempts = 2;

  final FfmpegService _ffmpeg;
  final GalleryService _gallery;

  bool _cancelled = false;

  /// Cancela el lote: detiene FFmpeg en curso y no procesa más nombres.
  Future<void> cancel() async {
    _cancelled = true;
    await _ffmpeg.cancelAll();
  }

  /// Nombre de carpeta automático: `Lote_YYYYMMDD_HHMM`.
  static String batchFolderName([DateTime? now]) {
    final t = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Lote_${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}';
  }

  Future<BatchResult> run({
    required TemplateMedia template,
    required TextStyleConfig style,
    required List<String> names,
    required void Function(BatchProgress progress) onProgress,
  }) async {
    _cancelled = false;
    final galleryDir =
        '${template.isVideo ? 'Movies' : 'Pictures'}/InvitaPro/${batchFolderName()}';

    final tmpRoot = await getTemporaryDirectory();
    final work = Directory(p.join(
      tmpRoot.path,
      'invitapro_work_${DateTime.now().microsecondsSinceEpoch}',
    ));
    await work.create(recursive: true);

    ui.Image? templateImage;
    VideoProbe? inputProbe;
    if (template.isVideo) {
      inputProbe = await _ffmpeg.probeVideo(template.path);
    } else {
      templateImage = await OverlayRenderer.decodeImageFile(template.path);
    }

    final failures = <String, String>{};
    var ok = 0;
    final total = names.length;

    try {
      for (var i = 0; i < total; i++) {
        if (_cancelled) break;
        final name = names[i];
        void report(double inner) => onProgress(BatchProgress(
              current: i + 1,
              total: total,
              fraction: ((i + inner) / total).clamp(0.0, 1.0),
              currentName: name,
            ));
        report(0);

        // Nombre final visible en la galería (único por el prefijo de índice).
        final base =
            '${(i + 1).toString().padLeft(3, '0')}_${GalleryService.sanitize(name)}';

        try {
          final saved = template.isVideo
              ? await _renderVideo(
                  template: template,
                  inputProbe: inputProbe,
                  style: style,
                  name: name,
                  index: i,
                  base: base,
                  workDir: work.path,
                  galleryDir: galleryDir,
                  onInner: report,
                )
              : await _renderImage(
                  template: template,
                  templateImage: templateImage!,
                  style: style,
                  name: name,
                  index: i,
                  base: base,
                  workDir: work.path,
                  galleryDir: galleryDir,
                );
          if (_cancelled) break;
          if (saved) {
            ok++;
            report(1);
          }
        } catch (e) {
          if (_cancelled) break;
          failures[name] = e.toString().replaceFirst('Exception: ', '');
        }
      }
    } finally {
      templateImage?.dispose();
      try {
        await work.delete(recursive: true);
      } catch (_) {}
    }

    return BatchResult(
      succeeded: ok,
      failures: failures,
      cancelled: _cancelled,
      galleryFolder: galleryDir,
    );
  }

  /// Etiqueta única por invitado + intento.
  String _tag(int index) => '${index}_${DateTime.now().microsecondsSinceEpoch}';

  Future<bool> _renderImage({
    required TemplateMedia template,
    required ui.Image templateImage,
    required TextStyleConfig style,
    required String name,
    required int index,
    required String base,
    required String workDir,
    required String galleryDir,
  }) async {
    final tag = _tag(index);
    final pngFile = File(p.join(workDir, 'img_$tag.png'));
    final jpgFile = File(p.join(workDir, 'img_$tag.jpg'));
    try {
      await OverlayRenderer.renderImageComposite(
        templateImage: templateImage,
        text: name,
        config: style,
        outPath: pngFile.path,
      );
      await _requireNonEmpty(pngFile, 'No se generó la imagen');

      var outFile = pngFile;
      var mime = 'image/png';
      var displayName = '$base.png';

      if (OverlayRenderer.isJpeg(template)) {
        final r = await _ffmpeg.pngToJpg(
          inputPng: pngFile.path,
          outputJpg: jpgFile.path,
        );
        if (r.cancelled || _cancelled) return false;
        if (r.success && await _isNonEmpty(jpgFile)) {
          outFile = jpgFile;
          mime = 'image/jpeg';
          displayName = '$base.jpg';
        } // si falla la conversión se conserva el PNG sin pérdida
      }

      await _gallery.save(
        file: outFile,
        mimeType: mime,
        relativeDir: galleryDir,
        displayName: displayName,
      );
      return true;
    } finally {
      await _safeDelete(pngFile);
      await _safeDelete(jpgFile);
    }
  }

  Future<bool> _renderVideo({
    required TemplateMedia template,
    required VideoProbe? inputProbe,
    required TextStyleConfig style,
    required String name,
    required int index,
    required String base,
    required String workDir,
    required String galleryDir,
    required void Function(double inner) onInner,
  }) async {
    Object lastError = 'Error desconocido';

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (_cancelled) return false;
      onInner(0);

      // Nombres únicos para ESTE invitado y ESTE intento.
      final tag = _tag(index);
      final overlayFile = File(p.join(workDir, 'overlay_$tag.png'));
      final outFile = File(p.join(workDir, 'temp_out_$tag.mp4'));

      try {
        // 1) PNG transparente (Canvas y coordenadas nuevos, solo con este nombre).
        final overlay = await OverlayRenderer.renderTextPng(
          text: name,
          config: style,
          mediaSize: template.size,
          outPath: overlayFile.path,
        );
        await _requireNonEmpty(overlayFile, 'No se generó el PNG del texto');

        // 2) FFmpeg: esperamos a que la sesión TERMINE y verificamos el resultado.
        final duration = template.durationMs;
        final r = await _ffmpeg.overlayPngOnVideo(
          inputVideo: template.path,
          overlayPng: overlayFile.path,
          x: overlay.x,
          y: overlay.y,
          outputPath: outFile.path,
          onTime: duration > 0
              ? (ms) => onInner((ms / duration).clamp(0.0, 0.99))
              : null,
        );
        if (r.cancelled || _cancelled) return false;
        if (!r.success) {
          lastError = 'FFmpeg falló: ${r.log.trim()}';
          continue;
        }

        // 3) Validar que el MP4 de salida esté completo y sea reproducible.
        final problem = await _validateVideo(outFile, inputProbe);
        if (problem != null) {
          lastError = problem;
          continue;
        }

        // 4) Publicar en MediaStore; solo tras confirmarlo se borran los temporales.
        await _gallery.save(
          file: outFile,
          mimeType: 'video/mp4',
          relativeDir: galleryDir,
          displayName: '$base.mp4',
        );
        return true;
      } catch (e) {
        lastError = e;
      } finally {
        await _safeDelete(overlayFile);
        await _safeDelete(outFile);
      }
    }
    throw Exception('$lastError (tras $maxAttempts intentos)');
  }

  /// `null` si el video es válido; si no, el motivo.
  Future<String?> _validateVideo(File out, VideoProbe? input) async {
    if (!await _isNonEmpty(out)) return 'El video de salida está vacío';
    final probe = await _ffmpeg.probeVideo(out.path);
    if (probe == null) return 'El video de salida está corrupto o incompleto';
    if (!probe.hasVideo) return 'El video de salida no tiene pista de video';
    if (input != null) {
      if (input.hasAudio && !probe.hasAudio) {
        return 'El video de salida perdió el audio';
      }
      if (input.durationMs > 0 && probe.durationMs > 0) {
        final tolerance = input.durationMs ~/ 20 > 1000 ? input.durationMs ~/ 20 : 1000;
        if ((probe.durationMs - input.durationMs).abs() > tolerance) {
          return 'Duración incorrecta (${probe.durationMs} ms vs ${input.durationMs} ms)';
        }
      }
    }
    return null;
  }

  Future<bool> _isNonEmpty(File f) async {
    try {
      return await f.exists() && await f.length() > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _requireNonEmpty(File f, String message) async {
    if (!await _isNonEmpty(f)) throw Exception(message);
  }

  Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
