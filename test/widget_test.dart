import 'package:flutter_test/flutter_test.dart';
import 'package:invita_pro/services/whatsapp_parser.dart';

void main() {
  test('limpia numeración, emojis y líneas vacías', () {
    const raw = '''
📋 Listas JUEVES 19 🎉

1. Jody Mauricio
2.madieska Yujra
3 Fernando Stone
- Ana   María 😀
• *Luis* Pérez

4️⃣ Carla
''';
    final out = WhatsAppParser.clean(raw);
    expect(out, [
      'Listas JUEVES 19',
      'Jody Mauricio',
      'madieska Yujra',
      'Fernando Stone',
      'Ana María',
      'Luis Pérez',
      'Carla',
    ]);
  });

  test('ignora líneas sin letras', () {
    expect(WhatsAppParser.clean('----\n19\n\n  \n5.'), isEmpty);
  });
}
