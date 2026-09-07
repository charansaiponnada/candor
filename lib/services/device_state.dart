import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models.dart';

/// Snapshot of device resource state at query time (PRD §6.3).
class DeviceState {
  final int batteryPercent;
  final ThermalLevel thermal;

  const DeviceState({required this.batteryPercent, required this.thermal});

  /// PRD §6.4: escalation allowed when battery >= 20% AND thermal < MODERATE.
  bool get allowsEscalation =>
      batteryPercent >= 20 && thermal.index < ThermalLevel.moderate.index;
}

/// Pollable device signal service + the single native MethodChannel bridge
/// (battery, thermal status, bundled-model file prep).
class DeviceStateMonitor {
  static const MethodChannel _channel = MethodChannel('candor/device');

  /// App-wide singleton; overridable in tests via `extends`.
  static DeviceStateMonitor instance = DeviceStateMonitor();

  /// Drives the app-wide "SIMULATED CONSTRAINED MODE" banner.
  final ValueNotifier<bool> simulating = ValueNotifier(false);
  int simulatedBattery = 5;
  ThermalLevel simulatedThermal = ThermalLevel.severe;

  /// Real device values (the debug panel shows these even while simulating).
  ///
  /// A null from the native bridge previously masked as "100% / NONE" — i.e. a
  /// broken channel silently unlocked escalation. Now it fails loudly: the
  /// query errors instead of pretending everything is fine.
  Future<DeviceState> readReal() async {
    final battery = await _channel.invokeMethod<int>('getBatteryPercent');
    final thermal = await _channel.invokeMethod<int>('getThermalStatus');
    if (battery == null || thermal == null) {
      throw StateError(
          'candor/device returned null (battery=$battery, thermal=$thermal) — '
          'native bridge is broken; not trusting defaults.');
    }
    return DeviceState(
        batteryPercent: battery, thermal: thermalFromInt(thermal));
  }

  /// What the router sees: simulated values while the demo toggle is on.
  Future<DeviceState> read() async {
    if (simulating.value) {
      return DeviceState(batteryPercent: simulatedBattery, thermal: simulatedThermal);
    }
    return readReal();
  }

  /// Stream-copy a bundled GGUF into app storage so llama.cpp can load it by path.
  Future<String> prepareModel(String name) async {
    final path = await _channel.invokeMethod<String>('prepareModel', {'name': name});
    if (path == null) throw StateError('prepareModel failed for $name');
    return path;
  }

  /// Bundled GGUF model names shipped in the APK assets (for the picker).
  Future<List<String>> listModels() async {
    return (await _channel.invokeListMethod<String>('listModels')) ?? const [];
  }
}