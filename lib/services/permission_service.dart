import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gestión de permisos según versión de Android:
///  - 13+ (API 33): READ_MEDIA_IMAGES / READ_MEDIA_VIDEO
///  - 10–12 (API 29–32): READ_EXTERNAL_STORAGE (la escritura vía MediaStore no necesita permiso)
///  - 9 o menor (API ≤28): READ/WRITE_EXTERNAL_STORAGE
class PermissionService {
  const PermissionService();

  static const _channel = MethodChannel('invitapro/media_store');

  Future<int> sdkInt() async {
    if (!Platform.isAndroid) return 0;
    try {
      return await _channel.invokeMethod<int>('sdkInt') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Pide acceso de lectura a medios (el selector del sistema funciona aunque
  /// se rechace, por eso no bloquea).
  Future<void> requestMediaRead() async {
    if (!Platform.isAndroid) return;
    final sdk = await sdkInt();
    if (sdk >= 33) {
      await [Permission.photos, Permission.videos].request();
    } else {
      await Permission.storage.request();
    }
  }

  /// Android 13+: permiso para mostrar la notificación de progreso.
  /// Si se rechaza, la generación sigue funcionando (solo sin notificación visible).
  Future<void> requestNotifications() async {
    if (!Platform.isAndroid) return;
    if (await sdkInt() >= 33) {
      await Permission.notification.request();
    }
  }

  /// `false` solo si el guardado es imposible (Android 9 o menor sin permiso).
  Future<bool> ensureWriteAccess() async {
    if (!Platform.isAndroid) return true;
    final sdk = await sdkInt();
    if (sdk > 0 && sdk <= 28) {
      return (await Permission.storage.request()).isGranted;
    }
    return true;
  }
}
