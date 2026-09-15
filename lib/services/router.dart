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
/// 1. read device state
/// 2. multi-step question ([needsDepth]) + device OK -> straight to Tier-2;
///    a 0.5B draft would be thrown away, so it isn't run
/// 3. otherwise run Tier-1 -> draft answer + confidence
/// 4. high confidence -> Tier-1; low + device OK -> Tier-2;
///    low (or multi-step) + constrained device -> Tier-1 with degradation note
///
/// "Low confidence" means a written `conf:` below [confidenceThreshold] (a
/// written 0 or `x` counts), an empty answer, a refusal, or a hedge ("I'm not
/// sure"). Calibration (on-device, Sep 2026): the 0.5B reports 0.95–0.99 even
/// when it confabulates and *omits* its tag on most good answers, so a missing
/// tag with a substantive answer is trusted — which is why its self-score
/// alone almost never escalated, and why the query-side [needsDepth] gate
/// exists. A Tier-2 refusal falls back to a Tier-1 answer rather than a snub.
class Router {
  static const double confidenceThreshold = 0.7;

  // Qwen2.5 smalls refuse innocuous asks; a snubbed answer is treated as low
  // confidence so a Tier-1 refusal escalates to the larger model. Stress-tested
  // in the 'Refusal gate' test group: common phrasings must match while
  // positive idioms ("can't help but", "can't help thinking") must not.
  static final RegExp _refusalRe = RegExp(
      r"i(?:'?m| am)\s+not\s+able"
      r"|(?:won'?t|will\s+not|would\s+not|can'?t|cannot)\s+be\s+able"
      r"|i'?m\s+sorry"
      r"|i'?m\s+afraid(?:\s+(?:i\s+)?(?:can'?t|cannot|unable|won'?t))?"
      r"|i'?d\s+rather\s+not"
      r"|(?:i|we)\s+don'?t\s+have\s+(?:the\s+)?ability"
      r"|(?:can'?t|cannot|couldn'?t|could\s+not|won'?t|would\s+not|unable\s+to)\s+"
      r"(?:fulfill|assist|help(?!\s+(?:but|think|feel|notice|wonder))|comply|"
      r"answer|provide|generate|create|complete|do\s+(?:that|this|it)"
      r"|give\s+you)"
      r"|(?:refuse\w*|decline\w*)\s+to"
      r"|as\s+(?:an\s+)?(?:ai|language\s+model|assistant)\b[^.!?\n]*"
      r"(?:can'?t|cannot|won'?t|unable|not\s+able|not\s+allowed)"
      r"|not\s+allowed"
      r"|not\s+something\s+(?:i|we)\s+can\s+do",
      caseSensitive: false);

  // The model saying it's unsure is a better signal than its own number.
  static final RegExp _hedgeRe = RegExp(
      r"\bi(?:['’]?m|\s+am)\s+(?:not\s+(?:sure|certain)|unsure)\b"
      r"|\bi\s+(?:don['’]?t|do\s+not)\s+(?:know|have\s+(?:enough\s+)?information)\b"
      r"|\bi\s+(?:can['’]?t|cannot)\s+be\s+(?:sure|certain)\b"
      r"|\bhard\s+to\s+say\b",
      caseSensitive: false);

  // ponytail: keyword heuristic, not a classifier. Upgrade path: train a tiny
  // router on escalations.jsonl once there's enough on-device data.
  static final RegExp _depthRe = RegExp(
      r'\bdifferences?\s+between\b'
      r'|\bcompar(?:e|ed|ing|ison)\b'
      r'|\b(?:vs|versus)\b'
      r'|\bstep[\s-]+by[\s-]+step\b'
      r'|\bpros\s+and\s+cons\b'
      r'|\badvantages?\s+and\s+disadvantages?\b'
      r'|\b(?:prove|derive|solve|analy[sz]e|evaluate)\b'
      r'|\b(?:write|implement|debug|fix|refactor)\b[^.?!\n]*'
      r'\b(?:code|function|program|script|class|algorithm|query|regex)\b',
      caseSensitive: false);

  /// Whether the *question* needs the larger model regardless of how
  /// confident the 0.5B claims to be: comparisons, step-by-step work,
  /// solve/prove/analyze, code, several questions at once, or a long ask.
  static bool needsDepth(String query) =>
      _depthRe.hasMatch(query) ||
      '?'.allMatches(query).length >= 2 ||
      query.trim().split(RegExp(r'\s+')).length >= 30;

  static bool _isLow(ModelResult r) =>
      // A written 0 counts; an unwritten 0.0 means "no tag" and is trusted.
      ((r.tagged || r.confidence > 0) && r.confidence < confidenceThreshold) ||
      r.text.trim().isEmpty ||
      _refusalRe.hasMatch(r.text) ||
      _hedgeRe.hasMatch(r.text);

  final ModelRunner runner;
  final DeviceStateMonitor monitor;
  final EscalationLog log;

  final ValueNotifier<int> tier1Count = ValueNotifier(0);
  final ValueNotifier<int> tier2Count = ValueNotifier(0);
  final ValueNotifier<int> constrainedCount = ValueNotifier(0);
  final ValueNotifier<double?> lastTier1Ms = ValueNotifier(null);
  final ValueNotifier<double?> lastEscalatedMs = ValueNotifier(null);

  Router(this.runner, this.monitor, this.log);

  /// [onStage] fires as each model starts, so the UI can say what's running.
  Future<RouterResult> answer(String query,
      {List<ChatMessage>? history,
      void Function(String token)? onToken,
      void Function(Tier tier)? onStage}) async {
    final sw = Stopwatch()..start();
    final device = await monitor.read();
    final canEscalate = device.allowsEscalation;
    final depth = needsDepth(query);

    // Tier-1 runs silently (it's scoring). Only Tier-2 streams into the UI.
    ModelResult? t1;
    if (!(depth && canEscalate)) {
      onStage?.call(Tier.tier1);
      t1 = await runner.generate(Tier.tier1, query, history: history);
    }
    final low = t1 != null && _isLow(t1);

    final bool escalated;
    final FinalTier tier;
    final String text;
    final String? note;
    String? t2Answer;

    if ((depth || low) && canEscalate) {
      onStage?.call(Tier.tier2);
      final t2 = await runner.generate(Tier.tier2, query,
          history: history, onToken: onToken);
      final t2Declined = _refusalRe.hasMatch(t2.text);
      if (t2Declined && t1 == null) {
        // Went straight to Tier-2 and it snubbed: get the small model's take.
        onStage?.call(Tier.tier1);
        t1 = await runner.generate(Tier.tier1, query, history: history);
      }
      // Don't let a slow refusal replace a usable Tier-1 answer.
      final keepT1 = t2Declined &&
          t1 != null &&
          t1.text.trim().isNotEmpty &&
          !_refusalRe.hasMatch(t1.text);
      escalated = true;
      tier = keepT1 ? FinalTier.tier1 : FinalTier.tier2;
      text = keepT1 ? t1.text : t2.text;
      t2Answer = t2.text; // log the failed trial too
      note = keepT1
          ? 'The larger on-device model declined this ask; kept the Tier-1 answer.'
          : t2Declined
              ? 'The larger on-device model also declined this one.'
              : depth && !low
                  ? 'Multi-step question: answered by the larger on-device model.'
                  : null;
    } else {
      escalated = false;
      if (depth || low) {
        tier = FinalTier.tier1Constrained;
        note = 'This needed the larger model, but the device is constrained '
            '(low battery or heat), so it was skipped: this may be less accurate.';
      } else {
        tier = FinalTier.tier1;
        note = null;
      }
      text = t1!.text; // only skipped on the escalate branch
    }

    final ms = sw.elapsedMilliseconds.toDouble();
    _recordStat(tier, ms);

    await log.write(EscalationRecord(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      query: query,
      tier1Answer: t1?.text ?? '',
      tier1Confidence: t1?.confidence ?? 0,
      batteryPercent: device.batteryPercent,
      thermalStatus: device.thermal,
      escalated: escalated,
      tier2Answer: t2Answer,
      finalTierUsed: tier.dbValue,
    ));

    return RouterResult(
      text: text,
      tier: tier,
      confidence: t1?.confidence ?? 0,
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
