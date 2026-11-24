import 'package:flutter/widgets.dart';

import 'guest_entry.dart';
import 'template_media.dart';
import 'text_style_config.dart';

/// Estado compartido entre las 3 pantallas (plantilla, estilo, invitados).
class ProjectState extends ChangeNotifier {
  TemplateMedia? _template;
  TextStyleConfig _style = const TextStyleConfig();
  String _sampleText = 'Gerson Flores';
  final List<GuestEntry> _guests = [];

  TemplateMedia? get template => _template;
  TextStyleConfig get style => _style;
  String get sampleText => _sampleText;
  List<GuestEntry> get guests => List.unmodifiable(_guests);
  int get guestCount => _guests.length;

  /// Nombres no vacíos, en orden.
  List<String> get guestNames => _guests
      .map((g) => g.name.trim())
      .where((n) => n.isNotEmpty)
      .toList(growable: false);

  void setTemplate(TemplateMedia template) {
    _template = template;
    notifyListeners();
  }

  void updateStyle(TextStyleConfig style) {
    _style = style;
    notifyListeners();
  }

  void setSampleText(String text) {
    _sampleText = text;
    notifyListeners();
  }

  void replaceGuests(Iterable<String> names) {
    _guests
      ..clear()
      ..addAll(names.map(GuestEntry.new));
    notifyListeners();
  }

  /// Agrega nombres al final de la lista existente.
  void appendGuests(Iterable<String> names) {
    _guests.addAll(names.map(GuestEntry.new));
    notifyListeners();
  }

  void clearGuests() {
    _guests.clear();
    notifyListeners();
  }

  void addGuest([String name = '']) {
    _guests.add(GuestEntry(name));
    notifyListeners();
  }

  void removeGuest(int id) {
    _guests.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  /// Edición de texto en línea: no notifica para no reconstruir la lista
  /// mientras se escribe (el contador se actualiza con [touch]).
  void renameGuest(int id, String name) {
    for (final g in _guests) {
      if (g.id == id) {
        g.name = name;
        break;
      }
    }
  }

  void touch() => notifyListeners();
}

/// Acceso al [ProjectState] desde cualquier widget.
class ProjectScope extends InheritedNotifier<ProjectState> {
  const ProjectScope({
    super.key,
    required ProjectState state,
    required super.child,
  }) : super(notifier: state);

  static ProjectState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ProjectScope>();
    assert(scope != null, 'ProjectScope no encontrado en el árbol de widgets');
    return scope!.notifier!;
  }
}
