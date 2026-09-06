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

    test('confidence exactly at threshold (0.7) is NOT low -> Tier-1', () async {
      final r = await makeRouter(
        const DeviceState(batteryPercent: 90, thermal: ThermalLevel.none),
        confidence: 0.7,
      ).answer('q');

      expect(r.tier, FinalTier.tier1);
    });

    test('confidence just below threshold (0.69) escalates', () async {
      final r = await makeRouter(
        const DeviceState(batteryPercent: 90, thermal: ThermalLevel.none),
        confidence: 0.69,
      ).answer('q');

      expect(r.tier, FinalTier.tier2);
    });

    test('empty Tier-1 answer escalates even with high confidence', () async {
      final routing = makeRouter(
        const DeviceState(batteryPercent: 90, thermal: ThermalLevel.none),
        confidence: 0.99,
      );
      runner.resultBuilder = (tier) => tier == Tier.tier1
          ? const ModelResult(text: '', confidence: 0.99)
          : const ModelResult(text: 't2 answer', confidence: 0);

      final r = await routing.answer('q');
      expect(r.tier, FinalTier.tier2);
      expect(runner.generations, [Tier.tier1, Tier.tier2]);
    });

    test('missing conf tag (0.0) escalates on a healthy device', () async {
      final r = await makeRouter(
        const DeviceState(batteryPercent: 90, thermal: ThermalLevel.none),
        confidence: 0.0,
      ).answer('what can you do');

      expect(r.tier, FinalTier.tier2);
    });
  });

  group('Confidence tag parsing', () {
    test('parses the strict two-line format and strips the tag', () {
      final r = ModelRunner.cleanTaggedAnswer('conf:0.87\n12 is the answer.');
      expect(r.$1, '12 is the answer.');
      expect(r.$2, 0.87);
    });

    test('accepts case/format variants (Conf=, confidence=, <…>)', () {
      expect(ModelRunner.cleanTaggedAnswer('Conf=0.99\nHello').$2, 0.99);
      expect(
          ModelRunner.cleanTaggedAnswer('Confidence=0.87\nHello').$2, 0.87);
      expect(
          ModelRunner.cleanTaggedAnswer('confidence=<0.95>\nHello').$2, 0.95);
      expect(
          ModelRunner.cleanTaggedAnswer('conf:<0.95>\nHello').$2, 0.95);
    });

    test('tag-only reply -> empty answer (empty gate escalates)', () {
      final x = ModelRunner.cleanTaggedAnswer('Conf=<X>');
      expect(x.$1, isEmpty);
      expect(x.$2, 0.0); // "x" marker means cannot confirm
      final n = ModelRunner.cleanTaggedAnswer('Conf=<0.99>');
      expect(n.$1, isEmpty);
      expect(n.$2, 0.99);
    });

    test('unparsable tag line -> text preserved (not mangled), 0.0', () {
      final r = ModelRunner.cleanTaggedAnswer('Conf=<confusing>');
      expect(r.$1, contains('Conf'));
      expect(r.$2, 0.0);
    });

    test('missing tag -> whole text, 0.0 (can knock confidence below 0.7)',
        () {
      final r = ModelRunner.cleanTaggedAnswer(
          'Dasara is celebrated with great fervour in Telangana.');
      expect(r.$1, contains('Dasara'));
      expect(r.$2, 0.0);
    });

    test('prose mentioning confidence mid-answer is not treated as a tag', () {
      final r = ModelRunner.cleanTaggedAnswer(
          'My confidence in this answer is 0.98 but here it goes.');
      expect(r.$1, startsWith('My confidence'));
      expect(r.$2, 0.0);
      expect(r.$1, contains('here it goes'));
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
  ModelResult Function(Tier tier)? resultBuilder;
  final List<Tier> generations = [];

  @override
  Future<ModelResult> generate(Tier tier, String query,
      {void Function(String token)? onToken}) async {
    generations.add(tier);
    return resultBuilder?.call(tier) ??
        (tier == Tier.tier1
            ? ModelResult(text: 't1 answer', confidence: confidence)
            : const ModelResult(text: 't2 answer', confidence: 0));
  }
}

class _StubMonitor extends DeviceStateMonitor {
  DeviceState state;
  _StubMonitor(this.state);

  @override
  Future<DeviceState> read() async => state;
}