import 'dart:ui' show Size;

enum TemplateType { image, video }

/// Plantilla elegida por el usuario junto con su resolución REAL en píxeles.
class TemplateMedia {
  const TemplateMedia({
    required this.path,
    required this.type,
    required this.width,
    required this.height,
    this.durationMs = 0,
  });

  final String path;
  final TemplateType type;
  final int width;
  final int height;

  /// Solo para videos; se usa para calcular el progreso real de FFmpeg.
  final int durationMs;

  bool get isVideo => type == TemplateType.video;
  Size get size => Size(width.toDouble(), height.toDouble());
  double get aspectRatio => width / height;

  String get extension {
    final dot = path.lastIndexOf('.');
    return dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  }

  static const videoExtensions = {'mp4', 'mov', 'm4v', 'mkv', 'webm', '3gp'};
  static const imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};
}
