import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models.dart';
import 'device_state.dart';
import 'model_runner.dart';

/// Escalation log as one JSON line per query (PRD §6.5). Backs the future
/// self-improvement research, not used live.
class EscalationLog {
  final File file;
  EscalationLog(this.file);

  static Future<EscalationLog> create() async {
    final dir = await getApplicationDocumentsDirectory();
    return EscalationLog(File('${dir.path}/escalations.jsonl'));
  }

  Future<void> write(EscalationRecord record) async {
    await file.writeAsString('${jsonEncode(record.toJson())}\n', mode: FileMode.append);
  }
}

/// The two-tier router. Per query (PRD §6.4):
/// 1. run Tier-1 -> draft answer + confidence
/// 2. read device state
/// 3. high confidence -> Tier-1; low + device OK -> Tier-2;
///    low + constrained device -> Tier-1 with degradation note
///
/// "Low confidence" means a parsed `conf:` below [confidenceThreshold], an
/// empty answer, or a refusal. Calibration (on-device, Sep 2026): the 0.5B
/// *omits* its tag on most good answers (creative asks included) and refuses
/// only when genuinely stuck, so a missing tag with a substantive, non-refusal
/// answer is trusted as-is — NOT escalated. Escalation is worth its ~30–50 s
/// on this hardware only when Tier-1 actually signals struggle (low tag, empty,
/// refusal). A Tier-2 refusal falls back to Tier-1's draft rather than
/// replacing a good answer with a snub.
class Router {
  static const double confidenceThreshold = 0.7;

  // Qwen2.5 smalls refuse innocuous asks; a snubbed answer is treated as low
  // confidence so a Tier-1 refusal escalates to the larger model.
  static final RegExp _refusalRe = RegExp(
      r"i'?m\s+not\s+able|i'?m\s+sorry|(?:can'?t|cannot|unable)\s+"
      r"(?:fulfill|assist|help|comply|answer)|not\s+allowed",
      caseSensitive: false);

  final ModelRunner runner;
  final DeviceStateMonitor monitor;
  final EscalationLog log;

  final ValueNotifier<int> tier1Count = ValueNotifier(0);
  final ValueNotifier<int> tier2Count = ValueNotifier(0);
  final ValueNotifier<int> constrainedCount = ValueNotifier(0);
  final ValueNotifier<double?> lastTier1Ms = ValueNotifier(null);
  final ValueNotifier<double?> lastEscalatedMs = ValueNotifier(null);

  Router(this.runner, this.monitor, this.log);

  Future<RouterResult> answer(String query,
      {void Function(String token)? onToken}) async {
    final sw = Stopwatch()..start();

    // Tier-1 runs silently (it's scoring). Only the chosen final answer
    // streams into the UI. ponytail: stream the Tier-1 draft too and swap it
    // on escalation if that "draft-then-replace" effect is wanted in the demo.
    final t1 = await runner.generate(Tier.tier1, query);
    final device = await monitor.read();
    // A parsed tag of 0.0 means "missing/unparsable", not "zero" — and with a
    // substantive, non-refusal answer that is trusted (see class doc).
    final lowConfidence = (t1.confidence > 0 &&
            t1.confidence < confidenceThreshold) ||
        t1.text.trim().isEmpty ||
        _refusalRe.hasMatch(t1.text);
    final canEscalate = device.allowsEscalation;

    final bool escalated;
    final FinalTier tier;
    final String text;
    final String? note;
    String? t2Answer;

    if (lowConfidence && canEscalate) {
      final t2 = await runner.generate(Tier.tier2, query, onToken: onToken);
      final t2Declined = _refusalRe.hasMatch(t2.text);
      // Don't let a slow refusal replace a usable Tier-1 draft.
      final keepT1 = t2Declined && t1.text.trim().isNotEmpty;
      escalated = true;
      tier = keepT1 ? FinalTier.tier1 : FinalTier.tier2;
      text = keepT1 ? t1.text : t2.text;
      t2Answer = t2.text; // log the failed trial too
      note = keepT1
          ? 'The larger on-device model declined this ask; kept the Tier-1 answer.'
          : (t2Declined
              ? 'The larger on-device model also declined this one.'
              : null);
    } else {
      escalated = false;
      if (lowConfidence) {
        tier = FinalTier.tier1Constrained;
        note = 'Low confidence, and this device is constrained: the larger '
            'model was not run, so this may be less accurate.';
      } else {
        tier = FinalTier.tier1;
        note = null;
      }
      text = t1.text;
    }

    final ms = sw.elapsedMilliseconds.toDouble();
    _recordStat(tier, ms);

    await log.write(EscalationRecord(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      query: query,
      tier1Answer: t1.text,
      tier1Confidence: t1.confidence,
      batteryPercent: device.batteryPercent,
      thermalStatus: device.thermal,
      escalated: escalated,
      tier2Answer: t2Answer,
      finalTierUsed: tier.dbValue,
    ));

    return RouterResult(
      text: text,
      tier: tier,
      confidence: t1.confidence,
      note: note,
      latencyMs: ms,
    );
  }

  void _recordStat(FinalTier tier, double ms) {
    switch (tier) {
      case FinalTier.tier1:
        tier1Count.value++;
        lastTier1Ms.value = ms;
      case FinalTier.tier1Constrained:
        constrainedCount.value++;
        lastTier1Ms.value = ms;
      case FinalTier.tier2:
        tier2Count.value++;
        lastEscalatedMs.value = ms;
    }
  }
}