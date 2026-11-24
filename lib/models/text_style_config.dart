import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// Fuente seleccionable. Se usan familias del sistema Android para que el
/// texto se vea igual en el editor y en el render final sin depender de red.
/// Para fuentes propias, declararlas en `pubspec.yaml` y añadirlas aquí.
class FontOption {
  const FontOption({
    required this.label,
    required this.family,
    this.weight = FontWeight.w700,
    this.italic = false,
  });

  final String label;
  final String family;
  final FontWeight weight;
  final bool italic;
}

const List<FontOption> kFontOptions = [
  FontOption(label: 'Black', family: 'sans-serif-black', weight: FontWeight.w900),
  FontOption(label: 'Bold', family: 'sans-serif', weight: FontWeight.w800),
  FontOption(label: 'Condensada', family: 'sans-serif-condensed', weight: FontWeight.w800),
  FontOption(label: 'Serif', family: 'serif', weight: FontWeight.w800),
  FontOption(label: 'Casual', family: 'casual', weight: FontWeight.w700),
  FontOption(label: 'Cursiva', family: 'cursive', weight: FontWeight.w700),
  FontOption(label: 'Monoespaciada', family: 'monospace', weight: FontWeight.w700),
  FontOption(label: 'Itálica', family: 'sans-serif', weight: FontWeight.w700, italic: true),
];

/// Estilo + posición del texto del invitado.
///
/// Todo es **relativo** al tamaño de la plantilla para que el editor (pantalla)
/// y el render (resolución original) produzcan exactamente el mismo resultado:
///  - [xPct]/[yPct]: centro del texto, 0..1 respecto al ancho/alto del medio.
///  - [fontSizePct]: tamaño de fuente como fracción del ANCHO del medio.
///  - [strokeWidthPct]: grosor del contorno como fracción del tamaño de fuente.
@immutable
class TextStyleConfig {
  const TextStyleConfig({
    this.xPct = 0.5,
    this.yPct = 0.5,
    this.fontSizePct = 0.07,
    this.textColor = const Color(0xFFFFFFFF),
    this.strokeColor = const Color(0xFF000000),
    this.strokeWidthPct = 0.10,
    this.fontIndex = 0,
  });

  final double xPct;
  final double yPct;
  final double fontSizePct;
  final Color textColor;
  final Color strokeColor;
  final double strokeWidthPct;
  final int fontIndex;

  FontOption get font => kFontOptions[fontIndex.clamp(0, kFontOptions.length - 1)];

  TextStyleConfig copyWith({
    double? xPct,
    double? yPct,
    double? fontSizePct,
    Color? textColor,
    Color? strokeColor,
    double? strokeWidthPct,
    int? fontIndex,
  }) {
    return TextStyleConfig(
      xPct: xPct ?? this.xPct,
      yPct: yPct ?? this.yPct,
      fontSizePct: fontSizePct ?? this.fontSizePct,
      textColor: textColor ?? this.textColor,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidthPct: strokeWidthPct ?? this.strokeWidthPct,
      fontIndex: fontIndex ?? this.fontIndex,
    );
  }
}
