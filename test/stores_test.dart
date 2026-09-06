import 'dart:convert';
import 'dart:io';

import 'package:candor/models.dart';
import 'package:candor/services/stores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tmp = Directory.systemTemp.createTempSync('candor_stores');
  tearDownAll(() => tmp.deleteSync(recursive: true));

  late File convFile;
  ChatStore makeStore() {
    convFile = File('${tmp.path}/conversations.json');
    return ChatStore(convFile);
  }

  group('ChatMessage JSON', () {
    test('round-trips a full assistant message', () {
      final original = ChatMessage(
        fromUser: false,
        text: 'The answer.',
        tier: FinalTier.tier2,
        note: 'kept the Tier-1',
        latencyMs: 12.5,
        confidence: 0.87,
        toolKind: ToolKind.setTimer,
      );

      final restored = ChatMessage.fromJson(original.toJson());
      expect(restored.fromUser, false);
      expect(restored.text, 'The answer.');
      expect(restored.tier, FinalTier.tier2);
      expect(restored.note, 'kept the Tier-1');
      expect(restored.latencyMs, 12.5);
      expect(restored.confidence, 0.87);
      expect(restored.toolKind, ToolKind.setTimer);
      expect(restored.streaming, false); // never persisted
    });

    test('tier1_constrained and falseys round-trip', () {
      final m = ChatMessage(
        fromUser: false,
        text: 'ok',
        tier: FinalTier.tier1Constrained,
        latencyMs: 0,
        confidence: 0,
      );
      final r = ChatMessage.fromJson(m.toJson());
      expect(r.tier, FinalTier.tier1Constrained);
      expect(r.latencyMs, 0);
      expect(r.confidence, 0);
    });
  });

  group('Conversation JSON', () {
    test('round-trips id/title/timestamps and message list', () {
      final c = Conversation.newThread()
        ..title = 'a thread'
        ..messages.addAll([
          ChatMessage(fromUser: true, text: 'hi'),
          ChatMessage(fromUser: false, text: 'hello'),
        ]);

      final restored = Conversation.fromJson(c.toJson());
      expect(restored.id, c.id);
      expect(restored.title, 'a thread');
      expect(restored.createdAt, c.createdAt);
      expect(restored.updatedAt, c.updatedAt);
      expect(restored.messages.map((m) => m.text), ['hi', 'hello']);
      expect(restored.messages[1].fromUser, false);
    });

    test('newThread never collides and starts empty', () {
      final a = Conversation.newThread();
      final b = Conversation.newThread();
      expect(a.id, isNot(b.id));
      expect(a.messages, isEmpty);
    });
  });

  group('ChatStore', () {
    test('starts empty when the file is missing', () async {
      final store = makeStore();
      await store.init();
      expect(store.isInitialized, true);
      expect(store.conversations, isEmpty);
    });

    test('save -> reload round-trips conversations', () async {
      final store = makeStore();
      await store.init();
      store.conversations.add(Conversation.newThread()
        ..title = 'first'
        ..messages.add(ChatMessage(fromUser: true, text: 'q')));
      await store.save();

      final reloaded = makeStore();
      await reloaded.init();
      expect(reloaded.conversations, hasLength(1));
      expect(reloaded.conversations.single.title, 'first');
      expect(reloaded.conversations.single.messages.single.text, 'q');
    });

    test('corrupt file backs up to .bak and starts empty', () async {
      convFile.writeAsStringSync('{not valid json');
      final store = makeStore();
      await store.init();
      expect(store.conversations, isEmpty);
      expect(File('${convFile.path}.bak').existsSync(), true);
    });
  });

  group('SettingsStore', () {
    test('defaults match the bundled models', () {
      final s = SettingsStore.defaults();
      expect(s.tier1Model, tier1DefaultModel);
      expect(s.tier2Model, tier2DefaultModel);
      expect(s.displayName, '');
      expect(s.persona, '');
      expect(s.useGpu, false);
    });

    test('save -> reload round-trips user changes', () async {
      final file = File('${tmp.path}/settings.json');
      final s = SettingsStore(file);
      await s.load();
      s
        ..displayName = 'Sam'
        ..persona = 'short, plain answers'
        ..tier1Model = 'other.gguf'
        ..useGpu = true;
      await s.save();

      final r = SettingsStore(file);
      await r.load();
      expect(r.displayName, 'Sam');
      expect(r.persona, 'short, plain answers');
      expect(r.tier1Model, 'other.gguf');
      expect(r.tier2Model, tier2DefaultModel);
      expect(r.useGpu, true);
    });

    test('defaults instance never writes', () async {
      await SettingsStore.defaults().save(); // must not throw
      expect(File('__none__').existsSync(), false);
    });
  });

  test('file writes are valid JSON arrays', () async {
    final store = makeStore();
    await store.init();
    store.conversations.add(Conversation.newThread());
    await store.save();
    expect(jsonDecode(convFile.readAsStringSync()), isA<List<Object?>>());
  });
}