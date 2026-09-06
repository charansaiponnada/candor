import 'package:flutter/material.dart' hide Router;

import '../models.dart';
import '../services/device_state.dart';
import '../services/router.dart';
import 'debug_panel.dart';

class ChatScreen extends StatefulWidget {
  final Router router;
  final DeviceStateMonitor monitor;

  const ChatScreen({super.key, required this.router, required this.monitor});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final query = _input.text.trim();
    if (query.isEmpty || _sending) return;
    _input.clear();

    setState(() {
      _messages.add(ChatMessage(fromUser: true, text: query));
      _messages.add(ChatMessage(fromUser: false, text: '', streaming: true));
      _sending = true;
    });
    _scrollToBottom();

    final draft = _messages.last;
    try {
      final result =
          await widget.router.answer(query, onToken: (token) => _appendToken(draft, token));
      setState(() {
        draft
          ..streaming = false
          ..text = result.text
          ..tier = result.tier
          ..note = result.note
          ..latencyMs = result.latencyMs;
        _sending = false;
      });
    } catch (_) {
      setState(() {
        draft
          ..streaming = false
          ..text = 'Something went wrong running the model.';
        _sending = false;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: true));
  }

  void _appendToken(ChatMessage draft, String token) {
    if (!mounted) return;
    setState(() => draft.text += token);
    _scrollToBottom();
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animated) {
      _scroll
          .animateTo(target,
              duration: const Duration(milliseconds: 150), curve: Curves.easeOut)
          .ignore();
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Candor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Debug & demo controls',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DebugPanel(monitor: widget.monitor, router: widget.router),
            )),
          ),
        ],
      ),
      body: Column(
        children: [
          _SimulatedBanner(monitor: widget.monitor),
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(cs: cs)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _MessageBubble(message: _messages[i]),
                  ),
          ),
          _Composer(
            controller: _input,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _SimulatedBanner extends StatelessWidget {
  final DeviceStateMonitor monitor;
  const _SimulatedBanner({required this.monitor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: monitor.simulating,
      builder: (_, simulated, _) => simulated
          ? Material(
              color: cs.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: cs.onTertiaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'SIMULATED CONSTRAINED MODE — the router is seeing fake '
                        'battery/thermal values from the demo toggle.',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: cs.onTertiaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme cs;
  const _EmptyState({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Ask anything. Candor runs entirely on this device — two models, and '
          'it will tell you which one answered and why.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final align = message.fromUser ? MainAxisAlignment.end : MainAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: message.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: align,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!message.fromUser) ...[
                if (message.tier != null) _TierChip(tier: message.tier!, cs: cs),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: message.fromUser ? cs.primary : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message.text.isEmpty ? '…' : message.text,
                    style: TextStyle(
                      color: message.fromUser ? cs.onPrimary : cs.onSurface,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!message.fromUser && message.tier != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                message.streaming
                    ? '…'
                    : '${message.tier!.label}  •  ${(message.latencyMs ?? 0) / 1000}s',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          if (!message.fromUser && message.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Card(
                  color: cs.errorContainer,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.thermostat, size: 18, color: cs.onErrorContainer),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              message.note!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final FinalTier tier;
  final ColorScheme cs;
  const _TierChip({required this.tier, required this.cs});

  @override
  Widget build(BuildContext context) {
    final bg = switch (tier) {
      FinalTier.tier1 => cs.secondaryContainer,
      FinalTier.tier2 => cs.primaryContainer,
      FinalTier.tier1Constrained => cs.errorContainer,
    };
    final fg = switch (tier) {
      FinalTier.tier1 => cs.onSecondaryContainer,
      FinalTier.tier2 => cs.onPrimaryContainer,
      FinalTier.tier1Constrained => cs.onErrorContainer,
    };
    return Chip(
      label: Text(tier.label),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
      backgroundColor: bg,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Ask Candor a question…',
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: sending ? null : onSend,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(16),
              ),
              child: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}