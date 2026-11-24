/// Un invitado de la lista. El [id] es estable para que la UI conserve el
/// estado de cada fila al borrar/editar elementos.
class GuestEntry {
  GuestEntry(this.name) : id = _next++;

  static int _next = 0;

  final int id;
  String name;
}
