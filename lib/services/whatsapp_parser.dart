/// Limpia listas pegadas desde WhatsApp y devuelve solo nombres.
class WhatsAppParser {
  const WhatsAppParser._();

  // Emojis, pictogramas, banderas, selectores de variación, ZWJ, etc.
  static final RegExp _emoji = RegExp(
    r'[\u{1F000}-\u{1FAFF}'   // emoticonos, símbolos, transporte, suplementos
    r'\u{2600}-\u{27BF}'      // símbolos misceláneos y dingbats
    r'\u{2300}-\u{23FF}'      // técnicos (⌚ ⏰ ...)
    r'\u{2B00}-\u{2BFF}'      // flechas/estrellas (⭐ ⬆ ...)
    r'\u{2190}-\u{21FF}'      // flechas
    r'\u{2460}-\u{24FF}'      // números encerrados
    r'\u{FE00}-\u{FE0F}'      // selectores de variación
    r'\u{200D}\u{20E3}'       // ZWJ y keycap
    r'\u{E0020}-\u{E007F}'    // etiquetas (banderas regionales)
    r'\u{3030}\u{303D}\u{3297}\u{3299}\u{00A9}\u{00AE}\u{203C}\u{2049}\u{2122}\u{2139}'
    r']',
    unicode: true,
  );

  // Dígito + (FE0F) + 20E3 = "1️⃣"
  static final RegExp _keycap = RegExp(r'[0-9#*]\uFE0F?\u20E3', unicode: true);

  // Marcas invisibles de WhatsApp (LRM, RLM, embeddings, BOM, espacio de ancho cero).
  static final RegExp _invisible =
      RegExp(r'[\u200B\u200C\u200E\u200F\u202A-\u202E\u2060\uFEFF]');

  // Formato WhatsApp: *negrita* _cursiva_ ~tachado~ `mono`
  static final RegExp _formatting = RegExp(r'[*_~`]');

  // Viñetas / guiones / números al inicio: "1.", "2 ", "3)", "(4)", "- ", "• ", "-5.", "10 -"
  static final RegExp _leadingEnumeration = RegExp(
    r'^[\s\-\u2013\u2014\u2022\u00B7\u25AA\u25CF\u25CB\u25E6\u2023>.:#]*'
    r'(?:\(?\d{1,4}\s*[.):\-\u2013\u2014]*\s*)?'
    r'[\s\-\u2013\u2014\u2022\u00B7.:]*',
    unicode: true,
  );

  static final RegExp _multiSpace = RegExp(r'\s{2,}');

  // Puntuación sobrante al final ("Jody Mauricio ,", "Ana -").
  static final RegExp _trailingJunk = RegExp(r'[\s,;:\-\u2013\u2014.|/]+$');

  /// Limpia una sola línea. Devuelve cadena vacía si no queda texto útil.
  static String cleanLine(String raw) {
    var s = raw;
    s = s.replaceAll(_invisible, '');
    s = s.replaceAll(_keycap, ' ');
    s = s.replaceAll(_emoji, ' ');
    s = s.replaceAll(_formatting, '');
    s = s.replaceFirst(_leadingEnumeration, '');
    s = s.replaceAll(_trailingJunk, '');
    s = s.replaceAll('\t', ' ').replaceAll(_multiSpace, ' ').trim();
    // Una línea sin ninguna letra (ej. "----", "19") no es un nombre.
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(s)) return '';
    return s;
  }

  /// Limpia todo el texto pegado: una entrada por línea no vacía.
  static List<String> clean(String raw) {
    return raw
        .split(RegExp(r'\r\n|\r|\n'))
        .map(cleanLine)
        .where((l) => l.isNotEmpty)
        .toList();
  }
}
