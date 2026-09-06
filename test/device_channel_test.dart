import 'package:candor/services/device_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('candor/device');

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  test('listModels returns bundled GGUF names', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'listModels') return ['a.gguf', 'b.gguf'];
      return null;
    });

    expect(await DeviceStateMonitor.instance.listModels(), ['a.gguf', 'b.gguf']);
  });

  test('listModels falls back to empty when the host has none', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'listModels') return <String>[];
      return null;
    });

    expect(await DeviceStateMonitor.instance.listModels(), isEmpty);
  });
}