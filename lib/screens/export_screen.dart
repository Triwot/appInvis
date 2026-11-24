import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/batch_progress.dart';
import '../models/project_state.dart';
import '../services/batch_renderer.dart';
import '../services/foreground_service.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';

/// Pantalla 3: renderizado por lotes y exportación.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _permissions = const PermissionService();
  final _foreground = const ForegroundService();
  int _lastNotifiedKey = -1;

  BatchRenderer? _renderer;
  BatchProgress? _progress;
  BatchResult? _result;
  bool _running = false;
  bool _cancelling = false;

  @override
  void dispose() {
    if (_running) {
      _renderer?.cancel();
      _foreground.stop();
    }
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _start() async {
    final project = ProjectScope.of(context);
    final template = project.template;
    final names = project.guestNames;
    if (template == null || names.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();

    // Bloquea doble toque desde el primer instante.
    final renderer = BatchRenderer();
    final style = project.style;
    setState(() {
      _renderer = renderer;
      _running = true;
      _cancelling = false;
      _result = null;
      _lastNotifiedKey = -1;
      _progress = BatchProgress(
        current: 1,
        total: names.length,
        fraction: 0,
        currentName: names.first,
      );
    });

    if (!await _permissions.ensureWriteAccess()) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Se necesita permiso de almacenamiento para guardar los archivos.'),
      ));
      if (mounted) setState(() => _running = false);
      return;
    }
    await _permissions.requestNotifications();

    await WakelockPlus.enable(); // la pantalla no se apaga durante el lote
    await _foreground.start(
      title: 'InvitaPro',
      text: 'Generando invitaciones: 0 de ${names.length}...',
    );

    var finishedNormally = false;
    try {
      final result = await renderer.run(
        template: template,
        style: style,
        names: names,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
          _notifyProgress(p);
        },
      );
      finishedNormally = !result.cancelled;
      if (finishedNormally) {
        await _foreground.finish(
          title: result.failures.isEmpty
              ? 'Invitaciones listas'
              : 'Lote terminado con errores',
          text: '${result.succeeded} de ${names.length} generadas'
              '${result.failures.isEmpty ? '' : ' (${result.failures.length} con error)'}'
              ' en ${result.galleryFolder}',
        );
      }
      if (mounted) setState(() => _result = result);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error en el lote: $e')));
    } finally {
      if (!finishedNormally) await _foreground.stop();
      await WakelockPlus.disable();
      if (mounted) {
        setState(() {
          _running = false;
          _cancelling = false;
        });
      }
    }
  }

  /// Actualiza la notificación persistente solo cuando cambia el invitado o
  /// el porcentaje entero (evita saturar al sistema con cada estadística).
  void _notifyProgress(BatchProgress p) {
    final percent = (p.fraction * 100).floor();
    final key = p.current * 1000 + percent;
    if (key == _lastNotifiedKey) return;
    _lastNotifiedKey = key;
    _foreground.update(
      title: 'InvitaPro',
      text: 'Generando invitaciones: ${p.current} de ${p.total}...',
      percent: percent,
    );
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    await _renderer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final project = ProjectScope.of(context);
    final template = project.template;
    final count = project.guestNames.length;
    final ready = template != null && count > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Generar invitaciones')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCard(
            icon: template?.isVideo == true ? Icons.videocam : Icons.image,
            title: template == null
                ? 'Sin plantilla'
                : '${template.isVideo ? 'Video' : 'Imagen'} · ${template.width}×${template.height}',
            subtitle: template == null
                ? 'Ve a la pestaña “Plantilla” para elegir una.'
                : 'Posición X ${(project.style.xPct * 100).toStringAsFixed(1)}% · Y ${(project.style.yPct * 100).toStringAsFixed(1)}%',
            ok: template != null,
          ),
          const SizedBox(height: 10),
          _SummaryCard(
            icon: Icons.groups_2_outlined,
            title: '$count invitados',
            subtitle: count == 0
                ? 'Ve a la pestaña “Lista” para pegar los nombres.'
                : 'Se generará un archivo por invitado.',
            ok: count > 0,
          ),
          const SizedBox(height: 12),
          Text(
            'Se guardará automáticamente en ${template?.isVideo == false ? 'Pictures' : 'Movies'}/InvitaPro/Lote_AAAAMMDD_HHMM (fecha y hora de inicio).',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            'Puedes minimizar la app: la generación sigue en segundo plano con una notificación de progreso.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (!_running)
            FilledButton.icon(
              onPressed: ready ? _start : null,
              icon: const Icon(Icons.rocket_launch_outlined),
              label: Text(ready ? 'Generar $count invitaciones' : 'Completa los pasos previos'),
            ),
          if (_running && _progress != null)
            _ProgressCard(
              progress: _progress!,
              cancelling: _cancelling,
              onCancel: _cancel,
            ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            _ResultCard(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ok,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ok ? AppTheme.outline : Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: ok ? AppTheme.electricBlue : Colors.orange, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ),
          ),
          Icon(ok ? Icons.check_circle : Icons.error_outline,
              color: ok ? Colors.greenAccent : Colors.orange),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.progress,
    required this.cancelling,
    required this.onCancel,
  });

  final BatchProgress progress;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final pct = (progress.fraction * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.electricBlue.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cancelling
                ? 'Cancelando…'
                : 'Procesando ${progress.current} de ${progress.total}…',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(progress.currentName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 12,
              backgroundColor: AppTheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text('$pct%', style: const TextStyle(color: Colors.white60)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Puedes minimizar la app; el proceso sigue en segundo plano.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: cancelling ? null : onCancel,
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
              label: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final BatchResult result;

  @override
  Widget build(BuildContext context) {
    final failed = result.failures.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: failed == 0 && !result.cancelled
              ? Colors.greenAccent.withValues(alpha: 0.5)
              : Colors.orange.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.cancelled ? 'Lote cancelado' : 'Lote terminado',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text('✔ ${result.succeeded} archivos generados'),
          if (failed > 0) Text('✖ $failed con error', style: const TextStyle(color: Colors.orangeAccent)),
          const SizedBox(height: 6),
          Text('Carpeta: ${result.galleryFolder}',
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
          for (final e in result.failures.entries.take(5))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${e.key}: ${e.value}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
