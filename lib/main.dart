import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const InvitaProApp());
}

class InvitaProApp extends StatelessWidget {
  const InvitaProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InvitaPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const HomeShell(),
    );
  }
}
