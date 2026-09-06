/// Chat history list. Pops a [Conversation] back to the chat screen:
/// - tapping a row returns that conversation,
/// - "New conversation" returns a fresh empty one.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/stores.dart';

class ConversationsScreen extends StatefulWidget {
  final ChatStore store;
  const ConversationsScreen({super.key, required this.store});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = [...widget.store.conversations]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pop(Conversation.newThread()),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New chat'),
      ),
      body: sorted.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 40, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No chats yet',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Questions you ask land here.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final c = sorted[i];
                final last = c.messages.isEmpty ? null : c.messages.last;
                final title = c.title.isEmpty ? 'New chat' : c.title;
                final snippet = last?.text.trim() ?? 'No messages yet';
                return Dismissible(
                  key: ValueKey(c.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: cs.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
                  ),
                  onDismissed: (_) {
                    setState(() => widget.store.conversations
                        .removeWhere((x) => x.id == c.id));
                    unawaited(widget.store.save().catchError((_) {}));
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        title.isEmpty ? '?' : title[0].toUpperCase(),
                        style: TextStyle(color: cs.onPrimaryContainer),
                      ),
                    ),
                    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      snippet.replaceAll('\n', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(_clock(c.updatedAt),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    onTap: () => Navigator.of(context).pop(c),
                  ),
                );
              },
            ),
    );
  }

  static String _clock(int millis) {
    final t = DateTime.fromMillisecondsSinceEpoch(millis);
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}