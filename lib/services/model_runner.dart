import 'dart:io';

import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;

import '../models.dart';
import 'device_state.dart';
import 'stores.dart';

typedef BenchResult = ({
  String model,
  int loadMs,
  double tokensPerSec,
  int sizeBytes,
  String device,
  int threads,
});

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
/// even when wrong and often omits the tag or writes variants (`Conf=`,
/// `**conf:0.9**`, a tag on the last line). The parser accepts those; the
/// router decides what a missing tag means (see Router).
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

  // A whole tag line, tolerating what the 0.5B actually writes: markdown
  // (`**conf:0.9**`), trailing punctuation (`conf: 0.9.`), `Line 1:`, `<…>`.
  static final RegExp _tagRe = RegExp(
      r'^\s*(?:line\s*1\s*[:.)-]\s*)?[*_`"]*\s*conf(?:idence)?\s*[*_`"]*\s*[:=]?'
      r'\s*[*_`"]*\s*<?\s*([0-9]+(?:\.[0-9]+)?|x)?\s*>?\s*[*_`".,;]*\s*$',
      caseSensitive: false);

  // The same tag with the answer on the same line: `conf:0.9 Paris is…`.
  static final RegExp _inlineTagRe = RegExp(
      r'^\s*[*_`"]*conf(?:idence)?[*_`"]*\s*[:=]\s*<?\s*([0-9]+(?:\.[0-9]+)?)\s*>?'
      r'[*_`"]*[\s,;.:-]+(?=\S)',
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

  /// Whether a bundled model file (kept in app storage) is a Gemma-style GGUF.
  static String _templateFor(String modelName) =>
      modelName.toLowerCase().contains('gemma') ? 'gemma3' : 'chatml';

  /// On-device benchmark: load time, streaming tokens/sec, file size, device.
  /// Reuses the resident model when the requested model/gpu matches, so a
  /// second benchmark of the same model is instant and doesn't churn RAM.
  Future<BenchResult> benchmark(String modelName, {required bool gpu}) async {
    final sw = Stopwatch()..start();
    final path = await DeviceStateMonitor.instance.prepareModel(modelName);
    final gpuInfo = await _detectGpu();
    final layers = gpu && gpuInfo.vulkanSupported ? gpuInfo.recommendedGpuLayers : 0;
    if (_residentTier != null) await _llama.dispose();
    await _llama.loadModel(
        modelPath: path, threads: _threads, contextSize: _contextSize, gpuLayers: layers);
    final loadMs = sw.elapsedMilliseconds;
    _residentTier = Tier.tier1;
    _residentModel = modelName;
    _residentGpu = gpu;

    final gen = Stopwatch()..start();
    var tokens = 0;
    try {
      await for (final _ in _llama.generateChat(
        messages: [
          llama.ChatMessage(
              role: 'system', content: 'You are brief and direct.'),
          llama.ChatMessage(
              role: 'user', content: 'Name three colours of the ocean in one short line.'),
        ],
        template: _templateFor(modelName),
        maxTokens: 48,
        temperature: 0.7,
      )) {
        tokens++;
      }
    } catch (_) {}
    final elapsedS = gen.elapsedMilliseconds / 1000.0;

    final sizeBytes = await File(path).length();
    return (
      model: modelName,
      loadMs: loadMs,
      tokensPerSec: (elapsedS > 0 ? tokens / elapsedS : 0.0),
      sizeBytes: sizeBytes,
      device: gpu && gpuInfo.vulkanSupported ? gpuInfo.gpuName : 'CPU',
      threads: _threads,
    );
  }

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
    final sw = Stopwatch()..start();
    final modelName =
        tier == Tier.tier1 ? _settings.tier1Model : _settings.tier2Model;
    final gpuLayers = _settings.useGpu ? await _resolveGpuLayers() : 0;
    final s = _settings.sampling(tier);
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
        template: _templateFor(modelName),
        maxTokens: maxTokens,
        temperature: s.temperature,
        topP: s.topP,
        topK: s.topK,
        repeatPenalty: s.repeatPenalty,
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
      tagged: tier == Tier.tier1 && cleaned.$3,
      latencyMs: (sw.elapsedMilliseconds).toDouble(),
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

  /// Strips the `conf:…` tag (its own first or last line, or inline at the
  /// very start), returning `(answer, confidence, tagged)`. Missing or
  /// unparsable -> `0.0, tagged: false`, which the router trusts on a
  /// substantive answer. Prose like "My confidence is 0.98…" is not a tag.
  static (String, double, bool) cleanTaggedAnswer(String raw) {
    final lines = raw.trim().split('\n');
    if (lines.length > 1) {
      for (final i in [0, lines.length - 1]) {
        final m = _tagRe.firstMatch(lines[i]);
        if (m != null) {
          return (([...lines]..removeAt(i)).join('\n').trim(), _tagValue(m), true);
        }
      }
    } else {
      final m = _tagRe.firstMatch(raw);
      if (m != null) return ('', _tagValue(m), true);
    }
    final m = _inlineTagRe.firstMatch(raw);
    if (m != null) return (raw.substring(m.end).trim(), _tagValue(m), true);
    return (raw.trim(), 0.0, false);
  }

  static double _tagValue(RegExpMatch m) {
    final s = m.group(1);
    if (s == null || s.toLowerCase() == 'x') return 0.0;
    return double.tryParse(s)?.clamp(0.0, 1.0).toDouble() ?? 0.0;
  }
}