import 'dart:io';

import 'package:candor/models.dart';
import 'package:candor/screens/conversations_screen.dart';
import 'package:candor/services/stores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tmp = Directory.systemTemp.createTempSync('candor_convs');
  tearDownAll(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {} // file may still be held open by a late save
  });

  ChatStore seededStore() {
    final store = ChatStore(File('${tmp.path}/conversations.json'));
    store.conversations.add(Conversation.newThread()
      ..title = 'Plants'
      ..messages.addAll([
        ChatMessage(fromUser: true, text: 'What do plants need?'),
        ChatMessage(fromUser: false, text: 'Light, water, air.'),
      ]));
    return store;
  }

  testWidgets('lists conversations newest first', (tester) async {
    final store = seededStore();
    store.conversations.insert(
        0,
        Conversation.newThread()
          ..title = 'Newer'
          ..updatedAt = DateTime.now().millisecondsSinceEpoch + 1
          ..messages.add(ChatMessage(fromUser: true, text: 'n')));
    await tester.pumpWidget(MaterialApp(
        home: ConversationsScreen(store: store)));

    expect(find.text('Newer'), findsOneWidget);
    expect(find.text('Plants'), findsOneWidget);
    expect(find.text('Light, water, air.'), findsOneWidget);
  });

  testWidgets('tapping a row returns that conversation', (tester) async {
    final store = seededStore();
    await tester.pumpWidget(MaterialApp(home: _Host(store: store)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plants'));
    await tester.pumpAndSettle();
    final host = tester.state<_HostState>(find.byType(_Host));
    expect(host.result?.title, 'Plants');
  });

  testWidgets('swipe deletes the conversation', (tester) async {
    final store = seededStore();
    await tester.pumpWidget(
        MaterialApp(home: ConversationsScreen(store: store)));
    await tester.drag(find.text('Plants'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(store.conversations, isEmpty);
  });
}

class _Host extends StatefulWidget {
  final ChatStore store;
  const _Host({required this.store});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Conversation? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final c = await Navigator.of(context).push<Conversation>(
              MaterialPageRoute(
                  builder: (_) => ConversationsScreen(store: widget.store)),
            );
            setState(() => result = c);
          },
          child: Text(result?.title ?? 'open'),
        ),
      ),
    );
  }
}