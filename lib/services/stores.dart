/// Persistence: conversations (chat history) and user/model settings.
///
/// Both are plain JSON files in app documents — a few KB at this scale, so
/// each store rewrites its whole file on save. No DB dependency needed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models.dart';

/// The two models bundled in `android/app/src/main/assets/models/`
/// (`tools/download_models.ps1`). Settings default to these.
const tier1DefaultModel = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
const tier2DefaultModel = 'qwen2.5-1.5b-instruct-q4_k_m.gguf';

class ChatStore {
  final File file;
  List<Conversation> conversations = [];
  bool _initialized = false;

  ChatStore(this.file);

  static Future<ChatStore> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final store = ChatStore(File('${dir.path}/conversations.json'));
    await store.init();
    return store;
  }

  Future<void> init() async {
    try {
      if (await file.exists()) {
        final raw = await file.readAsString();
        conversations = (jsonDecode(raw) as List<Object?>)
            .map((e) => Conversation.fromJson(e as Map<String, Object?>))
            .toList();
      }
    } catch (_) {
      // Corrupt file (partial write, version change…): preserve it as .bak
      // instead of silently wiping a good history.
      try {
        if (await file.exists()) await file.rename('${file.path}.bak');
      } catch (_) {}
      conversations = [];
    }
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  Future<void> save() async {
    await file.writeAsString(
        jsonEncode(conversations.map((c) => c.toJson()).toList()));
  }
}

class SettingsStore extends ChangeNotifier {
  final File file;
  String displayName = '';
  String persona = '';
  String tier1Model = tier1DefaultModel;
  String tier2Model = tier2DefaultModel;
  bool useGpu = false;
  bool onboardingDone = false;
  String themeMode = 'system'; // 'system' | 'light' | 'dark'

  // Sampling (Prompt Lab). Per-tier so the sandbox can compare behaviour.
  double t1Temp = 0.7, t2Temp = 0.7;
  double t1TopP = 0.9, t2TopP = 0.9;
  int t1TopK = 40, t2TopK = 40;
  double t1RepeatPenalty = 1.1, t2RepeatPenalty = 1.1;

  SettingsStore(this.file);

  /// In-memory defaults; never saved (used for tests / no-file constructors).
  static SettingsStore defaults() => SettingsStore(File('__none__'));

  static Future<SettingsStore> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final store = SettingsStore(File('${dir.path}/settings.json'));
    await store.load();
    return store;
  }

  Future<void> load() async {
    try {
      if (!await file.exists()) return;
      final j = jsonDecode(await file.readAsString()) as Map<String, Object?>;
      displayName = j['displayName'] as String? ?? '';
      persona = j['persona'] as String? ?? '';
      tier1Model = j['tier1Model'] as String? ?? tier1DefaultModel;
      tier2Model = j['tier2Model'] as String? ?? tier2DefaultModel;
      useGpu = j['useGpu'] as bool? ?? false;
      onboardingDone = j['onboardingDone'] as bool? ?? false;
      themeMode = j['themeMode'] as String? ?? 'system';
      t1Temp = (j['t1Temp'] as num?)?.toDouble() ?? 0.7;
      t2Temp = (j['t2Temp'] as num?)?.toDouble() ?? 0.7;
      t1TopP = (j['t1TopP'] as num?)?.toDouble() ?? 0.9;
      t2TopP = (j['t2TopP'] as num?)?.toDouble() ?? 0.9;
      t1TopK = j['t1TopK'] as int? ?? 40;
      t2TopK = j['t2TopK'] as int? ?? 40;
      t1RepeatPenalty = (j['t1RepeatPenalty'] as num?)?.toDouble() ?? 1.1;
      t2RepeatPenalty = (j['t2RepeatPenalty'] as num?)?.toDouble() ?? 1.1;
    } catch (_) {
      // Broken settings -> defaults; no throw on startup.
    }
  }

  Future<void> save() async {
    if (file.path == '__none__') return;
    await file.writeAsString(jsonEncode({
      'displayName': displayName,
      'persona': persona,
      'tier1Model': tier1Model,
      'tier2Model': tier2Model,
      'useGpu': useGpu,
      'onboardingDone': onboardingDone,
      'themeMode': themeMode,
      't1Temp': t1Temp,
      't2Temp': t2Temp,
      't1TopP': t1TopP,
      't2TopP': t2TopP,
      't1TopK': t1TopK,
      't2TopK': t2TopK,
      't1RepeatPenalty': t1RepeatPenalty,
      't2RepeatPenalty': t2RepeatPenalty,
    }));
    notifyListeners();
  }

  /// The sampling params for a tier (used by ModelRunner + Prompt Lab).
  ({double temperature, double topP, int topK, double repeatPenalty})
      sampling(Tier tier) => tier == Tier.tier1
          ? (temperature: t1Temp, topP: t1TopP, topK: t1TopK, repeatPenalty: t1RepeatPenalty)
          : (temperature: t2Temp, topP: t2TopP, topK: t2TopK, repeatPenalty: t2RepeatPenalty);
}