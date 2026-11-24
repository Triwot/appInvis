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
class BatchRenderer {
  BatchRenderer({
    this._ffmpeg = const FfmpegService(),
    this._gallery = const GalleryService(),
  });

  final FfmpegService _ffmpeg;
  final GalleryService _gallery;

  bool _cancelled = false;

  /// Cancela el lote: detiene FFmpeg en curso y no procesa más nombres.
  Future<void> cancel() async {
    _cancelled = true;
    await _ffmpeg.cancelAll();
  }

  Future<BatchResult> run({
    required TemplateMedia template,
    required TextStyleConfig style,
    required List<String> names,
    required String eventName,
    required void Function(BatchProgress progress) onProgress,
  }) async {
    _cancelled = false;
    final event = GalleryService.sanitize(eventName, fallback: 'Evento');
    final galleryDir =
        '${template.isVideo ? 'Movies' : 'Pictures'}/InvitaPro/$event';

    final tmpRoot = await getTemporaryDirectory();
    final work = Directory(p.join(tmpRoot.path, 'invitapro_work'));
    if (await work.exists()) await work.delete(recursive: true);
    await work.create(recursive: true);

    ui.Image? templateImage;
    if (!template.isVideo) {
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

        final base =
            '${(i + 1).toString().padLeft(3, '0')}_${GalleryService.sanitize(name)}';
        try {
          if (template.isVideo) {
            await _renderVideo(
              template: template,
              style: style,
              name: name,
              base: base,
              workDir: work.path,
              galleryDir: galleryDir,
              onInner: report,
            );
          } else {
            await _renderImage(
              template: template,
              templateImage: templateImage!,
              style: style,
              name: name,
              base: base,
              workDir: work.path,
              galleryDir: galleryDir,
            );
          }
          if (_cancelled) break;
          ok++;
          report(1);
        } catch (e) {
          if (_cancelled) break;
          failures[name] = e.toString();
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

  Future<void> _renderImage({
    required TemplateMedia template,
    required ui.Image templateImage,
    required TextStyleConfig style,
    required String name,
    required String base,
    required String workDir,
    required String galleryDir,
  }) async {
    final pngPath = p.join(workDir, '$base.png');
    final png = await OverlayRenderer.renderImageComposite(
      templateImage: templateImage,
      text: name,
      config: style,
      outPath: pngPath,
    );

    var outFile = png;
    var mime = 'image/png';
    var displayName = '$base.png';

    if (OverlayRenderer.isJpeg(template)) {
      final jpgPath = p.join(workDir, '$base.jpg');
      final r = await _ffmpeg.pngToJpg(inputPng: pngPath, outputJpg: jpgPath);
      if (r.success && await File(jpgPath).exists()) {
        outFile = File(jpgPath);
        mime = 'image/jpeg';
        displayName = '$base.jpg';
      } else if (r.cancelled) {
        return;
      } // si falla la conversión se conserva el PNG sin pérdida
    }

    await _gallery.save(
      file: outFile,
      mimeType: mime,
      relativeDir: galleryDir,
      displayName: displayName,
    );
    await _safeDelete(png);
    await _safeDelete(outFile);
  }

  Future<void> _renderVideo({
    required TemplateMedia template,
    required TextStyleConfig style,
    required String name,
    required String base,
    required String workDir,
    required String galleryDir,
    required void Function(double inner) onInner,
  }) async {
    // 1) PNG transparente recortado con el texto (stroke + fill).
    final overlay = await OverlayRenderer.renderTextPng(
      text: name,
      config: style,
      mediaSize: template.size,
      outPath: p.join(workDir, '$base.overlay.png'),
    );

    // 2) FFmpeg: overlay + audio original sin recodificar.
    final outPath = p.join(workDir, '$base.mp4');
    final duration = template.durationMs;
    final r = await _ffmpeg.overlayPngOnVideo(
      inputVideo: template.path,
      overlayPng: overlay.file.path,
      x: overlay.x,
      y: overlay.y,
      outputPath: outPath,
      onTime: duration > 0
          ? (ms) => onInner((ms / duration).clamp(0.0, 0.99))
          : null,
    );
    await _safeDelete(overlay.file);

    if (r.cancelled || _cancelled) {
      await _safeDelete(File(outPath));
      return;
    }
    if (!r.success) {
      await _safeDelete(File(outPath));
      throw Exception('FFmpeg falló: ${r.log.trim()}');
    }

    // 3) Publicar en Movies/InvitaPro/<Evento>.
    final out = File(outPath);
    await _gallery.save(
      file: out,
      mimeType: 'video/mp4',
      relativeDir: galleryDir,
      displayName: '$base.mp4',
    );
    await _safeDelete(out);
  }

  Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
