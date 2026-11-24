import 'package:material_ui/material_ui.dart';

import '../models/project_state.dart';
import 'editor_screen.dart';
import 'export_screen.dart';
import 'guest_list_screen.dart';

/// Contenedor con navegación inferior entre las 3 pantallas.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _project = ProjectState();
  int _index = 0;

  @override
  void dispose() {
    _project.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProjectScope(
      state: _project,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            EditorScreen(isActive: _index == 0),
            GuestListScreen(onContinue: () => setState(() => _index = 2)),
            const ExportScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.edit_outlined),
              selectedIcon: Icon(Icons.edit),
              label: 'Plantilla',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Lista',
            ),
            NavigationDestination(
              icon: Icon(Icons.rocket_launch_outlined),
              selectedIcon: Icon(Icons.rocket_launch),
              label: 'Generar',
            ),
          ],
        ),
      ),
    );
  }
}
