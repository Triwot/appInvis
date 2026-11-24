import 'dart:io';

import 'package:flutter/services.dart';

/// Servicio en primer plano de Android (ver BatchForegroundService.kt):
/// mantiene viva la app y muestra una notificación persistente con el progreso.
class ForegroundService {
  const ForegroundService();

  static const _channel = MethodChannel('invitapro/foreground');

  Future<void> start({required String title, required String text}) =>
      _invoke('start', {'title': title, 'text': text});

  /// [percent] 0..100.
  Future<void> update({
    required String title,
    required String text,
    required int percent,
  }) =>
      _invoke('update', {'title': title, 'text': text, 'percent': percent});

  /// Detiene el servicio y muestra una notificación final (no persistente).
  Future<void> finish({required String title, required String text}) =>
      _invoke('finish', {'title': title, 'text': text});

  /// Detiene el servicio sin notificación final.
  Future<void> stop() => _invoke('stop', {});

  Future<void> _invoke(String method, Map<String, Object?> args) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (_) {
      // Un fallo de notificación nunca debe interrumpir la generación.
    }
  }
}
