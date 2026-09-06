import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;

import '../models.dart';
import 'device_state.dart';
import 'stores.dart';

/// Wraps the llama.cpp Flutter plugin.
///
/// The plugin supports exactly one loaded model at a time (`isModelLoaded` is
/// a single global flag), so models are loaded on demand (PRD §9). The last
/// loaded tier stays resident so consecutive same-tier queries skip the model
/// load; switching tiers disposes and reloads.
///
/// The plugin streams `String` tokens and exposes no logprobs, so the PRD's
/// requested token-logprob confidence can't be read from it without a fork. We
/// instead ask Tier-1 to open its reply with a `conf:<X>` line and parse it
/// from the same single generation pass (PRD §9 accepts a proxy).
///
/// Calibration (measured on-device 2026-09-06): Qwen2.5-0.5B reports 0.95–0.99
/// even when wrong, but *omits* the tag or writes variants (`Conf=`,
/// `confidence=`, `Conf=<X>`) when it can't answer. The router therefore treats
/// a missing/unparsable tag as low (0.0) confidence — "can't confirm ⇒ defer".
class ModelRunner {
  static const int _threads = 8;
  static const int _contextSize = 2048;

  // Qwen2.5 small instructs are refusal-prone on innocuous creative asks (a
  // known DPO artifact), so creativity is explicitly authorized in-system.
  // Keep the answer promise tight to bound generation time (the 1.5B runs
  // iteratively on this budget device).
  static const String _confidenceSystemPrompt =
      'You are a helpful assistant. Creative writing (poems, stories, haiku, '
      'jokes) is welcome and allowed. Reply in exactly two lines: line 1 is '
      '"conf:<X>" where X is a number from 0.00 to 1.00 giving your honest '
      'confidence in your answer; line 2 is your answer.';

  static const String _t2SystemPrompt =
      'You are a helpful assistant. Creative writing (poems, stories, haiku, '
      'jokes) is welcome and allowed. Answer the user directly in 4 sentences '
      'or fewer; do not ask follow-up questions.';

  static final RegExp _tagRe = RegExp(
      r'^\s*conf(?:idence)?\s*[:=]?\s*<?\s*([0-9]+(?:\.[0-9]+)?|x)?\s*>?\s*$',
      multiLine: true,
      caseSensitive: false);

  final llama.LlamaController _llama = llama.LlamaController();
  final SettingsStore _settings;
  Tier? _residentTier;
  String? _residentModel;
  bool? _residentGpu;
  llama.GpuInfo? _gpuInfo;

  /// Optional [SettingsStore] so the app can drive persona/name and the model
  /// + GPU choice from persisted settings. Defaults keep stub tests and the
  /// bare constructor working unchanged.
  ModelRunner({SettingsStore? settings})
      : _settings = settings ?? SettingsStore.defaults();

  /// Ensures both GGUFs are copied out of the APK into app storage. Model
  /// load itself is deferred to the first query that needs a tier.
  Future<void> load() async {
    final prepare = DeviceStateMonitor.instance.prepareModel;
    await prepare(_settings.tier1Model);
    await prepare(_settings.tier2Model);
  }

  /// Bundled GGUFs available for the model picker.
  Future<List<String>> listModels() => DeviceStateMonitor.instance.listModels();

  /// What the settings screen shows under the GPU switch.
  Future<(bool supported, String name)> gpuCapability() async {
    final g = await _detectGpu();
    if (!g.vulkanSupported) return (false, 'Vulkan is not supported on this device');
    return (true, g.gpuName == 'None' ? 'Vulkan ready' : g.gpuName);
  }

  Future<llama.GpuInfo> _detectGpu() async =>
      _gpuInfo ??= await _llama.detectGpu();

  /// Vulkan offload depth: the plugin's recommendation (0 / 16 / 99), or 0
  /// (CPU-only) when Vulkan isn't available.
  Future<int> _resolveGpuLayers() async {
    final g = await _detectGpu();
    return g.vulkanSupported ? g.recommendedGpuLayers : 0;
  }

  Future<ModelResult> generate(Tier tier, String query,
      {List<ChatMessage>? history,
      void Function(String token)? onToken}) async {
    final modelName =
        tier == Tier.tier1 ? _settings.tier1Model : _settings.tier2Model;
    final gpuLayers = _settings.useGpu ? await _resolveGpuLayers() : 0;
    final messages = <llama.ChatMessage>[
      llama.ChatMessage(
          role: 'system',
          content: systemPromptFor(tier, _settings.displayName, _settings.persona)),
      ...historyTurns(history ?? const []).map(
          (t) => llama.ChatMessage(role: t.$1, content: t.$2)),
      llama.ChatMessage(role: 'user', content: query),
    ];

    if (_residentTier != tier ||
        _residentModel != modelName ||
        _residentGpu != _settings.useGpu) {
      if (_residentTier != null) await _llama.dispose();
      final path = await DeviceStateMonitor.instance.prepareModel(modelName);
      await _llama.loadModel(
          modelPath: path,
          threads: _threads,
          contextSize: _contextSize,
          gpuLayers: gpuLayers);
      _residentTier = tier;
      _residentModel = modelName;
      _residentGpu = _settings.useGpu;
    }

    final buf = StringBuffer();
    try {
      // Tier-1 answers are short; Tier-2 gets more room but stays capped so a
      // runaway generation can't turn into minutes on a budget CPU.
      final maxTokens = tier == Tier.tier1 ? 200 : 256;
      await for (final token in _llama.generateChat(
        messages: messages,
        template: 'chatml',
        maxTokens: maxTokens,
        temperature: 0.7,
      )) {
        buf.write(token);
        onToken?.call(token);
      }
    } catch (_) {
      // Generation failed mid-stream: release the model so the next call
      // starts from a clean slate.
      await _llama.dispose();
      _residentTier = null;
      rethrow;
    }

    final cleaned = cleanTaggedAnswer(buf.toString());
    return ModelResult(
      text: cleaned.$1,
      confidence: tier == Tier.tier1 ? cleaned.$2 : 0.0,
    );
  }

  void dispose() {
    _llama.dispose();
    _residentTier = null;
    _residentModel = null;
    _residentGpu = null;
  }

  /// Builds the system prompt for a tier. Name/persona are appended at the
  /// END, so Tier-1's exact two-line `conf:` output contract is untouched.
  static String systemPromptFor(Tier tier, String displayName, String persona) {
    final base =
        tier == Tier.tier1 ? _confidenceSystemPrompt : _t2SystemPrompt;
    final name = displayName.trim();
    final p = persona.trim();
    if (name.isEmpty && p.isEmpty) return base;
    final extras = <String>[
      if (name.isNotEmpty) 'Address the user as $name.',
      if (p.isNotEmpty) 'Persona: $p',
    ];
    return '$base\n${extras.join('\n')}';
  }

  /// Prior turns for ChatML, newest-first scan so the oldest of the kept turns
  /// is the one dropped when the ceiling is hit. Empty rows are skipped,
  /// adjacent same-role turns merge (tool cards read as assistant turns).
  static List<(String, String)> historyTurns(List<ChatMessage> history,
      {int maxTurns = 6}) {
    final acc = <(String, String)>[];
    for (var i = history.length - 1; i >= 0 && acc.length < maxTurns; i--) {
      final m = history[i];
      final text = m.text.trim();
      if (text.isEmpty) continue;
      final role = m.fromUser ? 'user' : 'assistant';
      if (acc.isNotEmpty && acc.last.$1 == role) continue;
      acc.add((role, text));
    }
    return acc.reversed.toList();
  }

  /// Strips the leading `conf:…` line, returning `(answer, confidence)` with
  /// 0.0 when the tag is missing/unparsable (router reads that as "cannot
  /// confirm", per on-device calibration).
  static (String, double) cleanTaggedAnswer(String raw) {
    final lines = raw.trim().split('\n');
    if (lines.length > 1) {
      final m = _tagRe.firstMatch(lines.first);
      if (m != null) {
        return (lines.skip(1).join('\n').trim(), _tagValue(m));
      }
    }
    // Single-line partial compliance (`conf=0.9 The answer is…`) — only when
    // the tag is the very first thing, so prose like "My confidence is 0.98…"
    // is not mangled.
    final m = _tagRe.firstMatch(raw);
    if (m != null && m.start == 0) {
      return (raw.substring(m.end).trimLeft(), _tagValue(m));
    }
    return (raw.trim(), 0.0);
  }

  static double _tagValue(RegExpMatch m) {
    final s = m.group(1);
    if (s == null || s.toLowerCase() == 'x') return 0.0;
    return double.tryParse(s)?.clamp(0.0, 1.0).toDouble() ?? 0.0;
  }
}