import 'dart:io';

import 'package:candor/screens/settings_screen.dart';
import 'package:candor/services/model_runner.dart';
import 'package:candor/services/stores.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tmp = Directory.systemTemp.createTempSync('candor_settings');
  tearDownAll(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {} // a pending save may still hold the file
  });

  const channel = MethodChannel('candor/device');
  setUp(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'listModels') return ['t1.gguf', 't2_large.gguf'];
    return null;
  }));
  tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));

  Future<void> pump(WidgetTester tester, SettingsStore store) async {
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(store: store, runner: ModelRunner(settings: store)),
    ));
    await tester.pump(); // let the model list future resolve
  }

  testWidgets('typing a name persists to the store', (tester) async {
    final store = SettingsStore(File('${tmp.path}/settings.json'));
    await pump(tester, store);

    await tester.enterText(find.byKey(const ValueKey('display-name')), 'Sam');
    await tester.pump();

    expect(store.displayName, 'Sam');
  });

  testWidgets('persona field persists', (tester) async {
    final store = SettingsStore(File('${tmp.path}/settings.json'));
    await pump(tester, store);

    await tester.enterText(
        find.byWidgetPredicate((w) =>
                w is TextField && w.decoration?.labelText == 'Persona'),
        'terse and honest');
    await tester.pump();

    expect(store.persona, 'terse and honest');
  });

  testWidgets('model dropdown swaps the Tier-1 model', (tester) async {
    final store = SettingsStore(File('${tmp.path}/settings.json'));
    await pump(tester, store);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('Tier-1 model')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('t2_large.gguf').last);
    await tester.pumpAndSettle();

    expect(store.tier1Model, 't2_large.gguf');
    expect(store.tier2Model, tier2DefaultModel); // untouched
  });

  testWidgets('GPU switch flips the persisted flag', (tester) async {
    final store = SettingsStore(File('${tmp.path}/settings.json'));
    await pump(tester, store);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.text('Use GPU (Vulkan)'),
        find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(store.useGpu, true);
  });
}