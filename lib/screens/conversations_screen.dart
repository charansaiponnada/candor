/// Chat history list. Pops a [Conversation] back to the chat screen:
/// - tapping a row returns that conversation,
/// - "New conversation" returns a fresh empty one.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/stores.dart';
import '../widgets/glass.dart';

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
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Chats'),
      ),
      floatingActionButton: GlassFAB(
        onPressed: () => Navigator.of(context).pop(Conversation.newThread()),
        label: 'New chat',
        icon: const Icon(Icons.add_comment_outlined),
        extended: true,
      ),
      body: sorted.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassCircle(
                    size: 80,
                    surfaceLevel: GlassSurfaceLevel.level2,
                    child: Icon(Icons.chat_bubble_outline,
                        size: 40, color: cs.textTertiary),
                  ),
                  const SizedBox(height: 16),
                  Text('No chats yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: cs.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Questions you ask land here.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.textTertiary)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 80, 16, 88),
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
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: Icon(Icons.delete_outline, color: cs.onError),
                  ),
                  onDismissed: (_) {
                    setState(() => widget.store.conversations
                        .removeWhere((x) => x.id == c.id));
                    unawaited(widget.store.save().catchError((_) {}));
                  },
                  child: GlassCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    surfaceLevel: GlassSurfaceLevel.level2,
                    border: GlassBorder.subtle,
                    onTap: () => Navigator.of(context).pop(c),
                    child: Row(
                      children: [
                        GlassCircle(
                          size: 40,
                          surfaceLevel: GlassSurfaceLevel.level3,
                          child: Text(
                            title.isEmpty ? '?' : title[0].toUpperCase(),
                            style: TextStyle(
                                color: cs.accent,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                          color: cs.textPrimary,
                                          fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                snippet.replaceAll('\n', ' '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_clock(c.updatedAt),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.textDisabled)),
                      ],
                    ),
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
