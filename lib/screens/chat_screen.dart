import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart' hide Router;
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../models.dart';
import '../services/device_state.dart';
import '../services/model_runner.dart';
import '../services/router.dart';
import '../services/skills.dart';
import '../services/speech.dart';
import '../services/stores.dart';
import '../services/tools.dart';
import 'conversations_screen.dart';
import 'debug_panel.dart';
import 'settings_screen.dart';
import 'skills_screen.dart';

/// Suggested first prompts. Chosen to demo both paths: the third typically
/// trips Tier-1's low/missing confidence and escalates to Tier-2; the last
/// runs a tool action instead of a model pass.
const _suggestions = [
  'What is the square root of 144?',
  'Explain recursion to a 12-year-old',
  "What's the difference between a LAN and a WAN?",
  'Set a timer for 10 minutes',
];

class ChatScreen extends StatefulWidget {
  final Router router;
  final DeviceStateMonitor monitor;
  final ChatStore chatStore;
  final SettingsStore settingsStore;
  final ModelRunner runner;

  const ChatScreen(
      {super.key,
      required this.router,
      required this.monitor,
      required this.chatStore,
      required this.settingsStore,
      required this.runner});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late Conversation _active;
  late List<ChatMessage> _messages;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Resume the most recent conversation, else start a fresh thread.
    _active = widget.chatStore.conversations.isEmpty
        ? Conversation.newThread()
        : widget.chatStore.conversations.last;
    _messages = _active.messages;
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openConversations() async {
    final picked = await Navigator.of(context).push<Conversation>(
      MaterialPageRoute(
          builder: (_) => ConversationsScreen(store: widget.chatStore)),
    );
    if (picked != null && mounted && picked.id != _active.id) {
      setState(() {
        _active = picked;
        _messages = picked.messages;
        _sending = false;
        _input.clear();
      });
      if (_messages.isNotEmpty) _scrollToBottom();
    }
  }

  /// Skills hub returns an example prompt; send it as a real query.
  Future<void> _openSkills() async {
    final example = await Navigator.of(context).push<String>(
      MaterialPageRoute(
          builder: (_) => SkillsScreen(store: widget.settingsStore)),
    );
    if (example != null && mounted) await _send(example);
  }

  /// Persist the thread: derive a title from the first user message and make
  /// sure the conversation lives in the store before saving.
  void _persist() {
    if (_active.title.isEmpty) {
      for (final m in _messages) {
        if (m.fromUser && m.text.trim().isNotEmpty) {
          _active.title = m.text.trim().replaceAll('\n', ' ');
          if (_active.title.length > 40) {
            _active.title = '${_active.title.substring(0, 40)}…';
          }
          break;
        }
      }
    }
    _active.updatedAt = DateTime.now().millisecondsSinceEpoch;
    if (!widget.chatStore.conversations.any((c) => c.id == _active.id)) {
      widget.chatStore.conversations.add(_active);
    }
    unawaited(widget.chatStore.save().catchError((_) {}));
  }

  Future<void> _send([String? preset]) async {
    final query = (preset ?? _input.text).trim();
    if (query.isEmpty || _sending) return;
    _input.clear();

    // Prior turns (excludes this query and the streaming draft) give the
    // model multi-turn context (PRD §4.1 personalization).
    final history = List<ChatMessage>.from(_messages);

    setState(() {
      _messages.add(ChatMessage(fromUser: true, text: query));
      _messages.add(ChatMessage(fromUser: false, text: '', streaming: true));
      _sending = true;
    });
    _scrollToBottom();

    final draft = _messages.last;

    // Tool context (PRD §6.7): a concrete action ask (open app, timer, SMS,
    // email, website) is executed on-device instead of a model pass.
    final tool = _detector.detect(query);
    if (tool != null) {
      draft.toolKind = tool.kind;
      final failure = await _executor.run(tool);
      if (!mounted) return;
      setState(() {
        draft
          ..streaming = false
          ..text = failure ?? tool.label;
        _sending = false;
      });
      _persist();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: true));
      return;
    }

    // On-device skills (PRD §6.7): calculator, converter, date/time, notes,
    // text helpers — deterministic, offline, no model pass.
    final skill = _skills.detect(query);
    if (skill != null) {
      draft.toolKind = skill.kind;
      final result = await _skills.run(skill);
      if (!mounted) return;
      setState(() {
        draft
          ..streaming = false
          ..text = result;
        _sending = false;
      });
      _persist();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: true));
      return;
    }

    try {
      final result = await widget.router.answer(query,
          history: history, onToken: (t) => _appendToken(draft, t));
      setState(() {
        draft
          ..streaming = false
          ..text = result.text
          ..tier = result.tier
          ..note = result.note
          ..confidence = result.confidence
          ..latencyMs = result.latencyMs;
        _sending = false;
      });
      _persist();
    } catch (_) {
      setState(() {
        draft
          ..streaming = false
          ..text = 'Something went wrong running the model.';
        _sending = false;
      });
      _persist();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: true));
  }

  void _appendToken(ChatMessage draft, String token) {
    if (!mounted) return;
    setState(() => draft.text += token);
    _scrollToBottom();
  }

  static const _detector = ToolDetector();
  static const _executor = ToolExecutor();
  static final _skills = SkillEngine();

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
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text('C',
                  style: TextStyle(
                      color: cs.onPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Candor',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text('Fully on-device · works offline',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view_outlined),
            tooltip: 'Skills',
            onPressed: _openSkills,
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Chat history',
            onPressed: _openConversations,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsScreen(
                  store: widget.settingsStore, runner: widget.runner),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Debug & demo controls',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  DebugPanel(monitor: widget.monitor, router: widget.router),
            )),
          ),
        ],
      ),
      body: Column(
        children: [
          _SimulatedBanner(monitor: widget.monitor),
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(onSuggestion: _send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) =>
                        _Reveal(child: _ChatRow(message: _messages[i])),
                  ),
          ),
          _Composer(controller: _input, sending: _sending, onSend: _send),
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
          ? Container(
              color: cs.tertiaryContainer,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.science_outlined,
                      size: 14, color: cs.onTertiaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Simulated constrained mode from the debug panel.',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final void Function(String) onSuggestion;
  const _EmptyState({required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Candor',
                style: t.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                    letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(
              'A private assistant that runs entirely on your phone.\n'
              'It answers with two on-device models — and tells you which one did.',
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 28),
            for (final s in _suggestions) ...[
              _Suggestion(prompt: s, onTap: () => onSuggestion(s)),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  final String prompt;
  final VoidCallback onTap;
  const _Suggestion({required this.prompt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(prompt,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface)),
        ),
      ),
    );
  }
}

/// One-shot entrance (fade + rise) for newly appended messages. Built with
/// state per row so existing rows never replay when the list grows.
class _Reveal extends StatefulWidget {
  final Widget child;
  const _Reveal({required this.child});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260))
    ..forward();
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(_a),
        child: widget.child,
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  final ChatMessage message;
  const _ChatRow({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (message.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onLongPress: () => _showMessageActions(context, message.text),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              margin: const EdgeInsets.only(bottom: 18, left: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(message.text,
                  style: TextStyle(color: cs.onPrimaryContainer, height: 1.35)),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.streaming)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [const _TypingDots(), const SizedBox(width: 10)],
                ),
              )
            else if (message.text.isNotEmpty)
              GestureDetector(
                onLongPress: () => _showMessageActions(context, message.text),
                child: _Markdown(text: message.text),
              ),
            if (message.toolKind != null && !message.streaming)
              GestureDetector(
                onLongPress: () => _showMessageActions(context, message.text),
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 18),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(toolIcon(message.toolKind!),
                          size: 18, color: cs.onTertiaryContainer),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(message.text,
                            style: TextStyle(
                                fontSize: 15,
                                color: cs.onTertiaryContainer,
                                height: 1.35)),
                      ),
                    ],
                  ),
                ),
              ),
            if (message.tier != null && !message.streaming)
              _TierPill(message: message),
          ],
        ),
      ),
    );
  }
}

/// Assistant replies render as Markdown (code blocks, lists, emphasis stay
/// readable); user messages stay plain bubbles.
class _Markdown extends StatelessWidget {
  final String text;
  const _Markdown({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    final style = base.copyWith(
      p: TextStyle(fontSize: 15, height: 1.5, color: cs.onSurface),
      code: TextStyle(
        fontSize: 13,
        color: cs.onSurface,
        backgroundColor: cs.surfaceContainerHighest,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      codeblockPadding: const EdgeInsets.all(10),
      blockquoteDecoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      listBullet: const TextStyle(height: 1.5),
    );
    return MarkdownBody(
      data: text,
      styleSheet: style,
      onTapLink: (text, href, title) {
        // Offline-first: links don't launch anything.
      },
    );
  }
}

/// The honesty pill: a tappable chip that reveals why this tier answered.
/// Tapping it is the "make the model explain itself" moment.
class _TierPill extends StatelessWidget {
  final ChatMessage message;
  const _TierPill({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tier = message.tier!;
    final lat = (message.latencyMs ?? 0) / 1000;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showTierInfo(context, message),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _tierColor(tier, cs),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${tier.label}  ·  ${lat.toStringAsFixed(1)} s'
                      '${_conf(message.confidence)}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.info_outline,
                        size: 13, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          if (message.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(message.note!,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }

  static String _conf(double? c) =>
      (c == null || c <= 0) ? '' : '  ·  conf ${c.toStringAsFixed(2)}';
}

void _showMessageActions(BuildContext context, String text) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('Copy'),
            onTap: () async {
              Navigator.pop(ctx);
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Copied to clipboard'), duration: Duration(seconds: 1)));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_rounded),
            title: const Text('Share…'),
            onTap: () async {
              Navigator.pop(ctx);
              await _shareText(text);
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    ),
  );
}

/// Android share sheet via the system ACTION_SEND chooser (offline — the text
/// goes to whatever share target the user picks, no Candor network involved).
Future<void> _shareText(String text) async {
  try {
    await AndroidIntent(
      action: 'android.intent.action.SEND',
      type: 'text/plain',
      arguments: {'android.intent.extra.TEXT': text},
    ).launchChooser('Share via');
  } catch (_) {
    // No share targets on this device; drop silently.
  }
}

/// Tapping the pill explains *why* this tier answered (PRD: the model-said-
/// so honesty moment). Text stays in one place so style + tests align.
String _tierExplanation(FinalTier tier) => switch (tier) {
      FinalTier.tier1 => 'The small on-device model (0.5B) answered with high '
          'confidence, so the larger model was not needed. Fastest and most '
          'efficient path.',
      FinalTier.tier2 => 'The small model was unsure or stuck, so Candor '
          'escalated to the larger on-device model (1.5B) for a better answer.',
      FinalTier.tier1Constrained => 'The small model was unsure, but this '
          'device is constrained (low battery or heat), so the larger model '
          'was skipped to protect it. This answer may be less accurate.',
    };

void _showTierInfo(BuildContext context, ChatMessage message) {
  final cs = Theme.of(context).colorScheme;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: _tierColor(message.tier!, cs),
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(message.tier!.label,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Text(_tierExplanation(message.tier!),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.5)),
            const SizedBox(height: 12),
            Text(
              'This answer: '
              '${((message.latencyMs ?? 0) / 1000).toStringAsFixed(1)} s'
              '${_TierPill._conf(message.confidence)}'
              '${message.note == null ? '' : '  ·  ${message.note}'}',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    ),
  );
}

Color _tierColor(FinalTier tier, ColorScheme cs) => switch (tier) {
      FinalTier.tier1 => cs.secondary,
      FinalTier.tier2 => cs.primary,
      FinalTier.tier1Constrained => cs.error,
    };

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Opacity(
              opacity: 0.25 + 0.75 * (((_c.value * 3 - i) % 1.0).clamp(0.0, 1.0)),
              child: Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer(
      {required this.controller, required this.sending, required this.onSend});

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final SpeechInput _speech = SpeechInput();
  bool _listening = false;
  bool _micSupported = true;

  @override
  void initState() {
    super.initState();
    _speech.available.then((ok) {
      if (mounted) setState(() => _micSupported = ok);
    });
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleSpeech() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      await _speech.start(
        onPartial: (t) => widget.controller.text = t,
        onError: (m) {
          if (!mounted) return;
          widget.controller.clear();
          setState(() => _listening = false);
          if (m == 'permission') {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Microphone permission is needed for voice input.')));
          }
        },
      );
      if (mounted) setState(() => _listening = true);
    } catch (_) {
      if (mounted) {
        setState(() => _listening = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Voice input isn\'t available on this device.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: _listening ? 'Stop listening' : 'Speak',
                onPressed: _micSupported ? _toggleSpeech : null,
                icon: Icon(
                  _listening ? Icons.stop_rounded : Icons.mic_none_rounded,
                  color: _listening ? cs.error : null,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Message Candor',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: (_) => widget.onSend(),
                ),
              ),
              AnimatedBuilder(
                animation: widget.controller,
                builder: (_, _) => IconButton.filled(
                  onPressed: widget.controller.text.trim().isEmpty || widget.sending
                      ? null
                      : widget.onSend,
                  icon: widget.sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_upward_rounded),
                  tooltip: 'Send',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}