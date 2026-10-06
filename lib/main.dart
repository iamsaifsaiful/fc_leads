import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/settings_controller.dart';
import 'services/settings_store.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FcLeadsApp(settings: SettingsController(SettingsStore())));
}

class FcLeadsApp extends StatelessWidget {
  const FcLeadsApp({super.key, required this.settings, this.services});

  final SettingsController settings;

  /// Lets tests swap in fake network services.
  final AppServices? services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FC Leads',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomeShell(settings: settings, services: services ?? AppServices()),
    );
  }
}
