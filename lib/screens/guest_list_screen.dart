import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/guest_entry.dart';
import '../models/project_state.dart';
import '../services/whatsapp_parser.dart';
import '../theme/app_theme.dart';

/// Pantalla 2: pegado masivo desde WhatsApp + limpieza + lista editable.
class GuestListScreen extends StatefulWidget {
  const GuestListScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  final _raw = TextEditingController();

  @override
  void dispose() {
    _raw.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) return;
    _raw.text = _raw.text.isEmpty ? data.text! : '${_raw.text}\n${data.text!}';
  }

  void _organize() {
    final project = ProjectScope.of(context);
    final names = WhatsAppParser.clean(_raw.text);
    FocusScope.of(context).unfocus();
    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron nombres en el texto pegado')),
      );
      return;
    }
    // Se agregan a la lista inferior y se vacía el cuadro para no duplicar
    // los nombres si se vuelve a pulsar el botón.
    project.appendGuests(names);
    _raw.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${names.length} invitados agregados a la lista')),
    );
  }

  Future<void> _clearGuestList() async {
    final project = ProjectScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar lista'),
        content: Text('Se eliminarán los ${project.guestCount} invitados de la lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) project.clearGuests();
  }

  @override
  Widget build(BuildContext context) {
    final project = ProjectScope.of(context);
    final guests = project.guests;

    return Scaffold(
      appBar: AppBar(title: const Text('Lista de invitados')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Texto pegado de WhatsApp',
                      style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _raw,
                      builder: (_, value, _) => TextButton.icon(
                        onPressed: value.text.isEmpty ? null : _raw.clear,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: Colors.white70,
                        ),
                        icon: const Icon(Icons.backspace_outlined, size: 18),
                        label: const Text('Borrar todo'),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: _raw,
                  minLines: 5,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText:
                        'Pega aquí la lista de WhatsApp…\n1. Jody Mauricio\n2.madieska Yujra\n3 Fernando Stone',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _paste,
                        icon: const Icon(Icons.content_paste),
                        label: const Text('Pegar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _organize,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Organizar invitados'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.electricBlue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${project.guestNames.length} invitados',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.electricBlue,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: guests.isEmpty ? null : _clearGuestList,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.redAccent,
                  ),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Limpiar lista'),
                ),
                TextButton.icon(
                  onPressed: project.addGuest,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir'),
                ),
              ],
            ),
          ),
          Expanded(
            child: guests.isEmpty
                ? const Center(
                    child: Text(
                      'Aún no hay invitados.\nPega la lista y pulsa “Organizar invitados”.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    itemCount: guests.length,
                    itemBuilder: (context, i) => _GuestRow(
                      key: ValueKey(guests[i].id),
                      index: i + 1,
                      entry: guests[i],
                      onChanged: (v) {
                        project.renameGuest(guests[i].id, v);
                        project.touch(); // refresca el contador
                      },
                      onDelete: () => project.removeGuest(guests[i].id),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: project.guestNames.isEmpty ? null : widget.onContinue,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continuar a exportar'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestRow extends StatefulWidget {
  const _GuestRow({
    super.key,
    required this.index,
    required this.entry,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final GuestEntry entry;
  final ValueChanged<String> onChanged;
  final VoidCallback onDelete;

  @override
  State<_GuestRow> createState() => _GuestRowState();
}

class _GuestRowState extends State<_GuestRow> {
  late final TextEditingController _c =
      TextEditingController(text: widget.entry.name);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '${widget.index}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _c,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(isDense: true, hintText: 'Nombre'),
              onChanged: widget.onChanged,
            ),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: widget.onDelete,
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
