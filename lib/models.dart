/// Shared data model: tiers, device signals, chat messages, conversations,
/// escalation log.
library;

import 'dart:math' show Random;

/// On-device actions/skills a query maps to (PRD §6.7 tool context). The
/// intent kinds run via platform intents (tools.dart); the skill kinds run as
/// pure Dart (skills.dart).
enum ToolKind {
  launchApp, setTimer, sms, email, website, deviceControl,
  calculate, converter, dateTime, note, textTool, random
}

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

/// Reverse of [FinalTierTable.dbValue]; unknown values fall back to tier1.
FinalTier finalTierFromDb(String v) => switch (v) {
      'tier2' => FinalTier.tier2,
      'tier1_constrained' => FinalTier.tier1Constrained,
      _ => FinalTier.tier1,
    };

class ChatMessage {
  final bool fromUser;
  String text;
  FinalTier? tier;
  String? note; // degradation note, only when constrained
  double? latencyMs;
  double? confidence; // Tier-1 self-reported, only when meaningful
  ToolKind? toolKind; // set when the message was an executed tool action
  bool streaming;

  ChatMessage({
    required this.fromUser,
    required this.text,
    this.tier,
    this.note,
    this.latencyMs,
    this.confidence,
    this.toolKind,
    this.streaming = false,
  });

  /// Streaming rows are transient UI state and never persisted.
  Map<String, Object?> toJson() => {
        'fromUser': fromUser,
        'text': text,
        'tier': tier?.dbValue,
        'note': note,
        'latencyMs': latencyMs,
        'confidence': confidence,
        'toolKind': toolKind?.name,
      };

  factory ChatMessage.fromJson(Map<String, Object?> j) => ChatMessage(
        fromUser: j['fromUser'] as bool? ?? false,
        text: j['text'] as String? ?? '',
        tier: switch (j['tier']) {
          final String s => finalTierFromDb(s),
          _ => null,
        },
        note: j['note'] as String?,
        latencyMs: (j['latencyMs'] as num?)?.toDouble(),
        confidence: (j['confidence'] as num?)?.toDouble(),
        toolKind: switch (j['toolKind']) {
          final String s => ToolKind.values.asNameMap()[s],
          _ => null,
        },
      );
}

/// A persisted conversation (a named/growable chat thread).
class Conversation {
  String id;
  String title;
  int createdAt;
  int updatedAt;
  final List<ChatMessage> messages;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  static Conversation newThread() => Conversation(
        id: '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}',
        title: '',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, Object?> j) => Conversation(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        createdAt: j['createdAt'] as int? ?? 0,
        updatedAt: j['updatedAt'] as int? ?? 0,
        messages: ((j['messages'] as List<Object?>?) ?? const [])
            .map((e) => ChatMessage.fromJson(e as Map<String, Object?>))
            .toList(),
      );
}

class ModelResult {
  final String text;
  final double confidence; // only meaningful for Tier-1
  final double latencyMs;
  const ModelResult({
    required this.text,
    required this.confidence,
    this.latencyMs = 0,
  });
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