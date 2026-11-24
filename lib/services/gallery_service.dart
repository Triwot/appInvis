import 'dart:io';

import 'package:flutter/services.dart';

/// Publica archivos en la galería usando MediaStore (ver MainActivity.kt),
/// respetando carpetas como `Movies/InvitaPro/MiEvento`.
class GalleryService {
  const GalleryService();

  static const _channel = MethodChannel('invitapro/media_store');

  /// [relativeDir]: ej. `Movies/InvitaPro/Boda`. Devuelve la ruta publicada.
  Future<String> save({
    required File file,
    required String mimeType,
    required String relativeDir,
    required String displayName,
  }) async {
    final result = await _channel.invokeMethod<String>('saveToGallery', {
      'path': file.path,
      'mimeType': mimeType,
      'relativeDir': relativeDir,
      'displayName': displayName,
    });
    return result ?? '$relativeDir/$displayName';
  }

  /// Quita caracteres no válidos para nombres de archivo/carpeta.
  static String sanitize(String input, {String fallback = 'archivo', int maxLength = 60}) {
    var s = input
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'^\.+'), '');
    if (s.length > maxLength) s = s.substring(0, maxLength);
    return s.isEmpty ? fallback : s;
  }
}
