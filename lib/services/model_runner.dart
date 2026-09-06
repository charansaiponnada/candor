import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;

import '../models.dart';
import 'device_state.dart';

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
  static const int _maxTokens = 256;
  // CPU-only for deterministic behavior across devices.
  // ponytail: switch to detectGpu().recommendedGpuLayers per-device if slow.
  static const int _gpuLayers = 0;

  static const String _t1Model = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const String _t2Model = 'qwen2.5-1.5b-instruct-q4_k_m.gguf';

  // First line must be the tag: conf:0.87 (variants handled by [_tagRe]).
  static const String _confidenceSystemPrompt =
      'You are a helpful assistant. Reply in exactly two lines. Line 1 is '
      '"conf:<X>" where X is a number from 0.00 to 1.00 giving your honest '
      'confidence in your answer. Line 2 is your answer.';

  static final RegExp _tagRe = RegExp(
      r'^\s*conf(?:idence)?\s*[:=]?\s*<?\s*([0-9]+(?:\.[0-9]+)?|x)?\s*>?\s*$',
      multiLine: true,
      caseSensitive: false);

  final llama.LlamaController _llama = llama.LlamaController();
  Tier? _residentTier;

  /// Ensures both GGUFs are copied out of the APK into app storage. Model
  /// load itself is deferred to the first query that needs a tier.
  Future<void> load() async {
    final prepare = DeviceStateMonitor.instance.prepareModel;
    await prepare(_t1Model);
    await prepare(_t2Model);
  }

  Future<ModelResult> generate(Tier tier, String query,
      {void Function(String token)? onToken}) async {
    final modelName = tier == Tier.tier1 ? _t1Model : _t2Model;
    final messages = [
      if (tier == Tier.tier1)
        llama.ChatMessage(role: 'system', content: _confidenceSystemPrompt),
      llama.ChatMessage(role: 'user', content: query),
    ];

    if (_residentTier != tier) {
      if (_residentTier != null) await _llama.dispose();
      final path = await DeviceStateMonitor.instance.prepareModel(modelName);
      await _llama.loadModel(
          modelPath: path,
          threads: _threads,
          contextSize: _contextSize,
          gpuLayers: _gpuLayers);
      _residentTier = tier;
    }

    final buf = StringBuffer();
    try {
      await for (final token in _llama.generateChat(
        messages: messages,
        template: 'chatml',
        maxTokens: _maxTokens,
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