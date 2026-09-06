import 'dart:convert';
import 'dart:io';

import 'package:candor/models.dart';
import 'package:candor/services/device_state.dart';
import 'package:candor/services/model_runner.dart';
import 'package:candor/services/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tmp = Directory.systemTemp.createTempSync('candor_test');
  final logFile = File('${tmp.path}/escalations.jsonl');

  late _StubRunner runner;
  late _StubMonitor monitor;
  late Router router;

  Router makeRouter(DeviceState state, {double confidence = 0.9}) {
    logFile.writeAsStringSync('');
    runner = _StubRunner()..confidence = confidence;
    monitor = _StubMonitor(state);
    router = Router(runner, monitor, EscalationLog(logFile));
    return router;
  }

  group('Router decision table (PRD §6.4)', () {
    test('high confidence + device OK -> Tier-1, no note', () async {
      final r = await makeRouter(
        const DeviceState(batteryPercent: 90, thermal: ThermalLevel.none),
      ).answer('what is 2+2');

      expect(r.tier, FinalTier.tier1);
      expect(r.text, 't1 answer');
      expect(r.note, isNull);
      expect(runner.generations, [Tier.tier1]);
    });

    test('low confidence + device OK -> escalates to Tier-2', () async {
      final r = await makeRouter(
        const DeviceState(batteryPercent: 90, thermal: ThermalLevel.none),
        confidence: 0.3,
      ).answer('explain dark matter');

      expect(r.tier, FinalTier.tier2);
      expect(r.text, 't2 answer');
      expect(runner.generations, [Tier.tier1, Tier.tier2]);
    });

    test('low confidence + constrained device -> Tier-1 (constrained), no escalation',
        () async {
      final r = await makeRouter(
        const DeviceState(batteryPercent: 5, thermal: ThermalLevel.severe),
        confidence: 0.3,
      ).answer('why is the sky blue');

      expect(r.tier, FinalTier.tier1Constrained);
      expect(r.text, 't1 answer');
      expect(r.note, isNotNull);
      expect(runner.generations, [Tier.tier1]); // Tier-2 never ran
    });

    test('low confidence + battery at 19% -> constrained even if thermal is fine',
        () async {
      final r = await makeRouter(
        const DeviceState(batteryPercent: 19, thermal: ThermalLevel.none),
        confidence: 0.2,
      ).answer('q');

      expect(r.tier, FinalTier.tier1Constrained);
    });

    test('low confidence + battery exactly 20% -> escalation allowed (>= threshold)',
        () async {
      final r = await makeRouter(
        const DeviceState(batteryPercent: 20, thermal: ThermalLevel.none),
        confidence: 0.2,
      ).answer('q');

      expect(r.tier, FinalTier.tier2);
    });

    test('low confidence + MODERATE thermal -> constrained (requires below MODERATE)',
        () async {
      final r = await makeRouter(
        const DeviceState(batteryPercent: 50, thermal: ThermalLevel.moderate),
        confidence: 0.2,
      ).answer('q');

      expect(r.tier, FinalTier.tier1Constrained);
    });

    test('confidence exactly at threshold (0.5) is NOT low -> Tier-1', () async {
      final r = await makeRouter(
        const DeviceState(batteryPercent: 90, thermal: ThermalLevel.none),
        confidence: 0.5,
      ).answer('q');

      expect(r.tier, FinalTier.tier1);
    });
  });

  group('Escalation log (PRD §6.5)', () {
    test('writes one JSON line per query with the final tier', () async {
      final router = makeRouter(
        const DeviceState(batteryPercent: 12, thermal: ThermalLevel.severe),
        confidence: 0.2,
      );

      await router.answer('a hard question');

      final lines = logFile.readAsLinesSync();
      expect(lines, hasLength(1));
      final record = jsonDecode(lines.single) as Map<String, Object?>;
      expect(record['query'], 'a hard question');
      expect(record['tier1Confidence'], 0.2);
      expect(record['batteryPercent'], 12);
      expect(record['thermalStatus'], 'severe');
      expect(record['escalated'], false);
      expect(record['tier2Answer'], isNull);
      expect(record['finalTierUsed'], 'tier1_constrained');
    });

    test('escalated query logs the Tier-2 answer', () async {
      final router = makeRouter(
        const DeviceState(batteryPercent: 90, thermal: ThermalLevel.none),
        confidence: 0.1,
      );

      await router.answer('tell me a story');

      final record = jsonDecode(logFile.readAsLinesSync().single) as Map<String, Object?>;
      expect(record['escalated'], true);
      expect(record['tier2Answer'], 't2 answer');
      expect(record['finalTierUsed'], 'tier2');
    });
  });
}

class _StubRunner extends ModelRunner {
  double confidence = 0.9;
  final List<Tier> generations = [];

  @override
  Future<ModelResult> generate(Tier tier, String query,
      {void Function(String token)? onToken}) async {
    generations.add(tier);
    return tier == Tier.tier1
        ? ModelResult(text: 't1 answer', confidence: confidence)
        : const ModelResult(text: 't2 answer', confidence: 0);
  }
}

class _StubMonitor extends DeviceStateMonitor {
  DeviceState state;
  _StubMonitor(this.state);

  @override
  Future<DeviceState> read() async => state;
}