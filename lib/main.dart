import 'package:flutter/material.dart' hide Router;

import 'screens/chat_screen.dart';
import 'services/device_state.dart';
import 'services/model_runner.dart';
import 'services/router.dart';
import 'services/stores.dart';

/// Everything the app needs wired once (first launch copies bundled GGUFs into
/// app storage; tiers load on demand at first query — see ModelRunner).
class AppServices {
  final Router router;
  final DeviceStateMonitor monitor;
  final ChatStore chatStore;
  final SettingsStore settingsStore;

  AppServices._(this.router, this.monitor, this.chatStore, this.settingsStore);

  static Future<AppServices> create() async {
    final monitor = DeviceStateMonitor.instance;
    final settings = await SettingsStore.create();
    final runner = ModelRunner();
    await runner.load();
    final log = await EscalationLog.create();
    final chatStore = await ChatStore.create();
    return AppServices._(
        Router(runner, monitor, log), monitor, chatStore, settings);
  }
}

void main() {
  // Must exist before AppServices.create() constructs LlamaController()s;
  // runApp() does this itself, but our services future starts at CandorApp
  // construction, which is before runApp()'s binding init.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CandorApp());
}

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
      // "Candor" = warm clay seed (blind-demo colour, feels honest + human);
      // full M3 role set generated from it.
      home: FutureBuilder<AppServices>(
        future: _services,
        builder: (context, snap) {
          if (snap.hasError) return _StartupView(error: '${snap.error}');
          if (!snap.hasData) return const _StartupView();
          return ChatScreen(
            router: snap.data!.router,
            monitor: snap.data!.monitor,
            chatStore: snap.data!.chatStore,
          );
        },
      ),
    );
  }
}

ThemeData _theme(Brightness brightness) => ThemeData(
      useMaterial3: true, // required on both themes, not just one
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFA64B2A), // warm clay, not corporate teal
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
                  Text('Preparing on-device models…'),
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