import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;

import '../models.dart';
import 'device_state.dart';

/// Wraps the llama.cpp Flutter plugin.
///
/// The plugin supports exactly one loaded model at a time (`isModelLoaded` is
/// a single global flag), so each generation loads the requested tier, runs it,
/// and disposes it (PRD §9's measured load-on-demand). Only one model sits in
/// RAM, and escalations pay a load swap instead of a resident-model startup.
///
/// The plugin streams `String` tokens and exposes no logprobs, so the PRD's
/// requested token-logprob confidence can't be read from it without a fork. We
/// instead ask Tier-1 to open its reply with a self-assessed confidence tag
/// (`conf=<0.00-1.00>`) and parse it from the same single generation pass —
/// PRD §9 accepts a proxy here and this one is visible for the demo.
class ModelRunner {
  static const int _threads = 4;
  static const int _contextSize = 2048;
  static const int _maxTokens = 512;
  // CPU-only for deterministic behavior across devices.
  // ponytail: switch to detectGpu().recommendedGpuLayers per-device if slow.
  static const int _gpuLayers = 0;

  static const String _t1Model = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const String _t2Model = 'qwen2.5-1.5b-instruct-q4_k_m.gguf';

  static const String _confidenceSystemPrompt =
      'You are a helpful assistant. Begin your reply with a single line '
      '"conf=<X>" where X is a number from 0.00 to 1.00 rating your own '
      'confidence in the answer, then write the answer.';

  static final RegExp _confRe = RegExp(r'conf\s*=\s*(0(?:\.\d+)?|1(?:\.0)?)');

  final llama.LlamaController _llama = llama.LlamaController();

  /// Ensures both GGUFs are copied out of the APK into app storage. Model load
  /// itself is deferred to the first query that needs a tier (see above).
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

    final path = await DeviceStateMonitor.instance.prepareModel(modelName);
    await _llama.loadModel(
        modelPath: path, threads: _threads, contextSize: _contextSize, gpuLayers: _gpuLayers);

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
    } finally {
      // Free the native model before the next tier loads, or the swap hangs
      // on the plugin's global isModelLoaded flag.
      await _llama.dispose();
    }

    final raw = buf.toString().trim();
    final isTier1 = tier == Tier.tier1;
    final confidence = isTier1 ? _parseConfidence(raw) : 0.0;
    return ModelResult(
      text: isTier1 ? _stripConfidenceTag(raw) : raw,
      confidence: confidence,
    );
  }

  void dispose() {
    _llama.dispose();
  }

  double _parseConfidence(String raw) {
    final m = _confRe.firstMatch(raw);
    final v = m == null ? null : double.tryParse(m.group(1)!);
    if (v == null) {
      // ponytail: unparsed tag -> neutral 0.5, so the router escalates when
      // the device allows it (good for demos; still an honest known limitation).
      return 0.5;
    }
    return v.clamp(0.0, 1.0).toDouble();
  }

  String _stripConfidenceTag(String raw) {
    final m = _confRe.firstMatch(raw);
    if (m == null || m.start > 40) return raw;
    return raw.substring(m.end).trimLeft();
  }
}