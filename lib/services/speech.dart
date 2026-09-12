/// Voice input (live captioning) via Android's on-device SpeechRecognizer.
///
/// Offline-first: the recognizer is asked to prefer the offline engine
/// (EXTRA_PREFER_OFFLINE) — no network is ever required. The mic button lives
/// in the chat composer; partial results stream into the message field.
library;

import 'package:flutter/services.dart';

class SpeechInput {
  static const MethodChannel _channel = MethodChannel('candor/speech');
  bool _listening = false;

  bool get listening => _listening;

  Future<bool> get available async {
    try {
      return await _channel.invokeMethod<bool>('available') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Starts recognition. [onPartial] fires as the user speaks (live caption),
  /// [onFinal] with the settled phrase, [onError] with a short message (e.g.
  /// "permission").
  Future<void> start({
    required void Function(String text) onPartial,
    required void Function(String message) onError,
  }) async {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPartial':
          onPartial(call.arguments as String? ?? '');
        case 'onFinal':
          onPartial(call.arguments as String? ?? '');
          _listening = false;
        case 'onResultEnded':
          _listening = false;
        case 'onError':
          _listening = false;
          onError(call.arguments as String? ?? 'recognizer');
      }
      return null;
    });
    _listening = true;
    try {
      await _channel.invokeMethod('start');
    } catch (_) {
      _listening = false;
      rethrow;
    }
  }

  Future<void> stop() async {
    _listening = false;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}