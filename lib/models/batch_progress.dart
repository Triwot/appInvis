/// Avance del procesamiento por lotes.
class BatchProgress {
  const BatchProgress({
    required this.current,
    required this.total,
    required this.fraction,
    required this.currentName,
  });

  /// Número (1-based) del invitado que se está procesando.
  final int current;
  final int total;

  /// Progreso global 0..1 (incluye el avance parcial del archivo actual).
  final double fraction;
  final String currentName;
}

/// Resultado final de un lote.
class BatchResult {
  const BatchResult({
    required this.succeeded,
    required this.failures,
    required this.cancelled,
    required this.galleryFolder,
  });

  final int succeeded;

  /// nombre del invitado -> motivo del error
  final Map<String, String> failures;
  final bool cancelled;

  /// Carpeta relativa en la galería (ej. `Movies/InvitaPro/Boda`).
  final String galleryFolder;
}
