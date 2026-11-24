import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class FfmpegResult {
  const FfmpegResult({required this.success, required this.cancelled, this.log = ''});

  final bool success;
  final bool cancelled;
  final String log;
}

/// Datos básicos de un video obtenidos con FFprobe.
class VideoProbe {
  const VideoProbe({
    required this.hasVideo,
    required this.hasAudio,
    required this.durationMs,
  });

  final bool hasVideo;
  final bool hasAudio;
  final int durationMs;
}

/// Envoltorio fino sobre ffmpeg_kit_flutter_new.
///
/// Cada método devuelve su Future SOLO cuando la sesión de FFmpeg terminó
/// realmente (callback de finalización), por lo que `await` es secuencial.
class FfmpegService {
  const FfmpegService();

  /// Superpone [overlayPng] sobre [inputVideo] en (x, y), copiando el audio
  /// original sin recodificar (`-c:a copy`).
  Future<FfmpegResult> overlayPngOnVideo({
    required String inputVideo,
    required String overlayPng,
    required int x,
    required int y,
    required String outputPath,
    void Function(int processedMs)? onTime,
  }) {
    final args = <String>[
      '-y',
      '-nostdin',
      '-hide_banner',
      '-i', inputVideo,
      '-i', overlayPng,
      '-filter_complex', '[0:v][1:v]overlay=$x:$y:format=auto[v]',
      '-map', '[v]',
      '-map', '0:a?', // audio opcional: no falla si el video no tiene
      '-c:v', 'libx264',
      '-preset', 'veryfast',
      '-crf', '20',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'copy',
      '-movflags', '+faststart',
      outputPath,
    ];
    return _run(args, onTime: onTime);
  }

  /// PNG -> JPG de alta calidad (dart:ui solo codifica PNG).
  Future<FfmpegResult> pngToJpg({
    required String inputPng,
    required String outputJpg,
  }) {
    return _run([
      '-y',
      '-nostdin',
      '-hide_banner',
      '-i', inputPng,
      '-q:v', '2',
      outputJpg,
    ]);
  }

  /// Inspecciona un video. Devuelve `null` si FFprobe no pudo leerlo
  /// (archivo corrupto/incompleto).
  Future<VideoProbe?> probeVideo(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      if (info == null) return null;
      final streams = info.getStreams();
      final seconds = double.tryParse(info.getDuration() ?? '') ?? 0;
      return VideoProbe(
        hasVideo: streams.any((s) => s.getType() == 'video'),
        hasAudio: streams.any((s) => s.getType() == 'audio'),
        durationMs: (seconds * 1000).round(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> cancelAll() => FFmpegKit.cancel();

  Future<FfmpegResult> _run(
    List<String> args, {
    void Function(int processedMs)? onTime,
  }) async {
    final completer = Completer<FfmpegResult>();
    try {
      await FFmpegKit.executeWithArgumentsAsync(
        args,
        (session) async {
          final rc = await session.getReturnCode();
          final cancelled = ReturnCode.isCancel(rc);
          final ok = ReturnCode.isSuccess(rc);
          var log = '';
          if (!ok && !cancelled) {
            log = await session.getAllLogsAsString() ?? '';
            if (log.length > 600) log = log.substring(log.length - 600);
          }
          if (!completer.isCompleted) {
            completer.complete(
              FfmpegResult(success: ok, cancelled: cancelled, log: log),
            );
          }
        },
        null,
        onTime == null ? null : (stats) => onTime(stats.getTime().round()),
      );
    } catch (e) {
      return FfmpegResult(success: false, cancelled: false, log: '$e');
    }
    return completer.future;
  }
}
