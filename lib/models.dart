/// Shared data model: tiers, device signals, chat messages, escalation log.
library;

enum Tier { tier1, tier2 }

/// Maps [PowerManager.getCurrentThermalStatus] (see DeviceStateMonitor).
enum ThermalLevel { none, light, moderate, severe }

ThermalLevel thermalFromInt(int v) => switch (v) {
      0 => ThermalLevel.none,
      1 => ThermalLevel.light,
      2 => ThermalLevel.moderate,
      _ => ThermalLevel.severe,
    };

/// How a query was ultimately answered, per PRD §6.4 §6.5.
enum FinalTier { tier1, tier1Constrained, tier2 }

extension FinalTierTable on FinalTier {
  String get label => switch (this) {
        FinalTier.tier1 => 'Tier-1',
        FinalTier.tier1Constrained => 'Tier-1 (constrained)',
        FinalTier.tier2 => 'Tier-2',
      };

  String get dbValue => switch (this) {
        FinalTier.tier1 => 'tier1',
        FinalTier.tier1Constrained => 'tier1_constrained',
        FinalTier.tier2 => 'tier2',
      };
}

class ChatMessage {
  final bool fromUser;
  String text;
  FinalTier? tier;
  String? note; // degradation note, only when constrained
  double? latencyMs;
  double? confidence; // Tier-1 self-reported, only when meaningful
  bool streaming;

  ChatMessage({
    required this.fromUser,
    required this.text,
    this.tier,
    this.note,
    this.latencyMs,
    this.confidence,
    this.streaming = false,
  });
}

class ModelResult {
  final String text;
  final double confidence; // only meaningful for Tier-1
  const ModelResult({required this.text, required this.confidence});
}

class RouterResult {
  final String text;
  final FinalTier tier;
  final double confidence;
  final String? note;
  final double latencyMs;
  const RouterResult({
    required this.text,
    required this.tier,
    required this.confidence,
    this.note,
    required this.latencyMs,
  });
}

/// One line of the escalation JSONL log; input for future self-improvement work.
class EscalationRecord {
  final int timestamp; // epoch millis
  final String query;
  final String tier1Answer;
  final double tier1Confidence;
  final int batteryPercent;
  final ThermalLevel thermalStatus;
  final bool escalated;
  final String? tier2Answer;
  final String finalTierUsed; // 'tier1' | 'tier1_constrained' | 'tier2'

  EscalationRecord({
    required this.timestamp,
    required this.query,
    required this.tier1Answer,
    required this.tier1Confidence,
    required this.batteryPercent,
    required this.thermalStatus,
    required this.escalated,
    this.tier2Answer,
    required this.finalTierUsed,
  });

  Map<String, Object?> toJson() => {
        'timestamp': timestamp,
        'query': query,
        'tier1Answer': tier1Answer,
        'tier1Confidence': tier1Confidence,
        'batteryPercent': batteryPercent,
        'thermalStatus': thermalStatus.name,
        'escalated': escalated,
        'tier2Answer': tier2Answer,
        'finalTierUsed': finalTierUsed,
      };
}