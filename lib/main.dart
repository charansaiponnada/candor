import 'package:flutter/material.dart' hide Router;

import 'screens/chat_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/device_state.dart';
import 'services/model_runner.dart';
import 'services/router.dart';
import 'services/stores.dart';
import 'theme/app_theme.dart';

/// Everything the app needs wired once (first launch copies bundled GGUFs into
/// app storage; tiers load on demand at first query — see ModelRunner).
class AppServices {
  final Router router;
  final DeviceStateMonitor monitor;
  final ChatStore chatStore;
  final SettingsStore settingsStore;
  final ModelRunner runner;

  AppServices._(
      this.router, this.monitor, this.chatStore, this.settingsStore, this.runner);

  static Future<AppServices> create() async {
    final monitor = DeviceStateMonitor.instance;
    final settings = await SettingsStore.create();
    final runner = ModelRunner(settings: settings);
    await runner.load();
    final log = await EscalationLog.create();
    final chatStore = await ChatStore.create();
    return AppServices._(
        Router(runner, monitor, log), monitor, chatStore, settings, runner);
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
    return FutureBuilder<AppServices>(
      future: _services,
      builder: (context, snap) {
        if (snap.hasError) {
          return MaterialApp(
              title: 'Candor',
              home: _StartupView(error: '${snap.error}'));
        }
        final services = snap.data;
        if (services == null) {
          return const MaterialApp(title: 'Candor', home: _StartupView());
        }
        // Theme follows the settings store so the Appearance picker in
        // Settings applies instantly across the whole app.
        return AnimatedBuilder(
          animation: services.settingsStore,
          builder: (_, _) => MaterialApp(
            title: 'Candor',
            theme: buildCandorTheme(brightness: Brightness.light),
            darkTheme: buildCandorTheme(brightness: Brightness.dark),
            themeMode: _themeMode(services.settingsStore.themeMode),
            // OLED Black glassmorphism theme — true black, white text, frosted glass.
            home: _Root(services: services),
          ),
        );
      },
    );
  }

  static ThemeMode _themeMode(String mode) => switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

/// Decides first-run onboarding vs. the main chat experience. Swapping the
/// whole subtree keeps onboarding off the nav stack (back button can't return).
class _Root extends StatefulWidget {
  final AppServices services;
  const _Root({required this.services});

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _onboarded = false;

  @override
  void initState() {
    super.initState();
    _onboarded = widget.services.settingsStore.onboardingDone;
  }

  Future<void> _finishOnboarding() async {
    final s = widget.services.settingsStore;
    s.onboardingDone = true;
    await s.save();
    if (mounted) setState(() => _onboarded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_onboarded) return OnboardingScreen(onDone: _finishOnboarding);
    final ap = widget.services;
    return ChatScreen(
      router: ap.router,
      monitor: ap.monitor,
      chatStore: ap.chatStore,
      settingsStore: ap.settingsStore,
      runner: ap.runner,
    );
  }
}

class _StartupView extends StatelessWidget {
  final String? error;
  const _StartupView({this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildCandorTheme(brightness: Brightness.dark),
      home: Scaffold(
        backgroundColor: CandorColors.black,
        body: Center(
          child: error == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: CandorColors.accent),
                    const SizedBox(height: 16),
                    Text('Preparing on-device models…',
                        style: TextStyle(color: CandorColors.textSecondary)),
                  ],
                )
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Startup failed: $error',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: CandorColors.textSecondary)),
                ),
        ),
      ),
    );
  }
}