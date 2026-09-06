import 'package:flutter/material.dart' hide Router;

import 'screens/chat_screen.dart';
import 'services/device_state.dart';
import 'services/model_runner.dart';
import 'services/router.dart';

/// Everything the app needs wired once (runs at first launch; ~seconds: copies
/// bundled GGUFs into app storage and loads both models).
class AppServices {
  final Router router;
  final DeviceStateMonitor monitor;

  AppServices._(this.router, this.monitor);

  static Future<AppServices> create() async {
    final monitor = DeviceStateMonitor.instance;
    final runner = ModelRunner();
    await runner.load();
    final log = await EscalationLog.create();
    return AppServices._(Router(runner, monitor, log), monitor);
  }
}

void main() => runApp(CandorApp());

class CandorApp extends StatelessWidget {
  CandorApp({super.key});

  final Future<AppServices> _services = AppServices.create();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Candor',
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      // "Candor" = trust-signaling teal seed; full M3 role set generated from it.
      home: FutureBuilder<AppServices>(
        future: _services,
        builder: (context, snap) {
          if (snap.hasError) return _StartupView(error: '${snap.error}');
          if (!snap.hasData) return const _StartupView();
          return ChatScreen(router: snap.data!.router, monitor: snap.data!.monitor);
        },
      ),
    );
  }
}

ThemeData _theme(Brightness brightness) => ThemeData(
      useMaterial3: true, // required on both themes, not just one
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00696B), // deep teal — trustworthy, distinctive
        brightness: brightness,
      ),
    );

class _StartupView extends StatelessWidget {
  final String? error;
  const _StartupView({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: error == null
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading on-device models…'),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Startup failed: $error',
                    textAlign: TextAlign.center),
              ),
      ),
    );
  }
}