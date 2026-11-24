import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../models/template_media.dart';
import '../models/text_style_config.dart';

/// Texto ya medido, listo para pintar (contorno + relleno).
class GuestTextLayout {
  GuestTextLayout._(this._stroke, this._fill, this.padding)
      : size = Size(_fill.width + padding * 2, _fill.height + padding * 2);

  final TextPainter? _stroke;
  final TextPainter _fill;
  final double padding;

  /// Tamaño total incluyendo el margen que ocupa el contorno.
  final Size size;

  void paint(Canvas canvas, Offset topLeft) {
    final at = topLeft + Offset(padding, padding);
    _stroke?.paint(canvas, at);
    _fill.paint(canvas, at);
  }
}

/// Dibujo del texto estilizado. Usado tanto por el editor (vista previa) como
/// por el render final, con `mediaWidth` distinto: así lo que se ve es lo que
/// se exporta (WYSIWYG).
class OverlayRenderer {
  const OverlayRenderer._();

  /// El texto nunca ocupa más de esta fracción del ancho (se reduce solo).
  static const double maxWidthFraction = 0.94;

  static GuestTextLayout layout({
    required String text,
    required TextStyleConfig config,
    required double mediaWidth,
  }) {
    var fontSize = config.fontSizePct * mediaWidth;

    TextPainter build(double size, {required bool stroke}) {
      final font = config.font;
      final paint = Paint();
      if (stroke) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          // Mitad del trazo queda bajo el relleno: se duplica para que el
          // grosor visible sea el del slider.
          ..strokeWidth = size * config.strokeWidthPct * 2
          ..color = config.strokeColor;
      } else {
        paint
          ..style = PaintingStyle.fill
          ..color = config.textColor;
      }
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: font.family,
            fontWeight: font.weight,
            fontStyle: font.italic ? FontStyle.italic : FontStyle.normal,
            fontSize: size,
            height: 1.1,
            foreground: paint,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      return tp;
    }

    var fill = build(fontSize, stroke: false);
    final maxW = mediaWidth * maxWidthFraction;
    if (fill.width > maxW) {
      fontSize *= maxW / fill.width;
      fill.dispose();
      fill = build(fontSize, stroke: false);
    }

    final strokePx = fontSize * config.strokeWidthPct;
    final stroke = strokePx > 0.01 ? build(fontSize, stroke: true) : null;
    final padding = strokePx + 1;
    return GuestTextLayout._(stroke, fill, padding);
  }

  /// Esquina superior izquierda del texto (con margen) dentro del medio.
  static Offset topLeft(GuestTextLayout l, TextStyleConfig c, Size media) =>
      Offset(
        c.xPct * media.width - l.size.width / 2,
        c.yPct * media.height - l.size.height / 2,
      );

  /// PNG transparente RECORTADO al texto. Devuelve archivo + posición (x, y)
  /// en píxeles donde debe superponerse sobre el video.
  static Future<({File file, int x, int y})> renderTextPng({
    required String text,
    required TextStyleConfig config,
    required Size mediaSize,
    required String outPath,
  }) async {
    final l = layout(text: text, config: config, mediaWidth: mediaSize.width);
    final tl = topLeft(l, config, mediaSize);
    final x = tl.dx.round();
    final y = tl.dy.round();
    final w = l.size.width.ceil().clamp(1, 16384);
    final h = l.size.height.ceil().clamp(1, 16384);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    l.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(outPath);
      await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
      return (file: file, x: x, y: y);
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  /// Dibuja plantilla (imagen) + texto a resolución original y guarda un PNG.
  /// [templateImage] se decodifica una vez por lote y se reutiliza.
  static Future<File> renderImageComposite({
    required ui.Image templateImage,
    required String text,
    required TextStyleConfig config,
    required String outPath,
  }) async {
    final size = Size(
      templateImage.width.toDouble(),
      templateImage.height.toDouble(),
    );
    final l = layout(text: text, config: config, mediaWidth: size.width);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(templateImage, Offset.zero, Paint()..filterQuality = FilterQuality.high);
    l.paint(canvas, topLeft(l, config, size));
    final picture = recorder.endRecording();
    final out = await picture.toImage(templateImage.width, templateImage.height);
    try {
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      final file = File(outPath);
      await file.writeAsBytes(data!.buffer.asUint8List(), flush: true);
      return file;
    } finally {
      out.dispose();
      picture.dispose();
    }
  }

  /// Decodifica una imagen del disco (respeta orientación EXIF).
  static Future<ui.Image> decodeImageFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  /// Tamaño real (px) de una imagen, con la misma decodificación del render.
  static Future<Size> imageSize(String path) async {
    final img = await decodeImageFile(path);
    final s = Size(img.width.toDouble(), img.height.toDouble());
    img.dispose();
    return s;
  }

  static bool isJpeg(TemplateMedia t) =>
      t.extension == 'jpg' || t.extension == 'jpeg';
}
