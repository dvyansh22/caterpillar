import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'voice_service.dart';

/// Real speech-to-text using the device OS engine (Android/iOS) or the browser
/// Web Speech API. Multilingual via [localeId] (en_IN / hi_IN / ta_IN).
class SpeechToTextVoiceService implements VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;

  @override
  bool get isAvailable => _available;

  @override
  Future<bool> init() async {
    _available = await _speech.initialize(
      onError: (e) {},
      onStatus: (_) {},
    );
    return _available;
  }

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    void Function(String message)? onError,
  }) async {
    if (!_available) {
      final ok = await init();
      if (!ok) {
        onError?.call('Speech recognition unavailable or microphone denied.');
        return;
      }
    }
    // Resolve the closest available locale (Android returns ids like en_IN / en-IN).
    final resolved = await _resolveLocale(localeId);
    await _speech.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: stt.SpeechListenOptions(
        localeId: resolved,
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  Future<String> _resolveLocale(String wanted) async {
    try {
      final locales = await _speech.locales();
      final target = wanted.replaceAll('-', '_').toLowerCase();
      for (final l in locales) {
        if (l.localeId.replaceAll('-', '_').toLowerCase() == target) return l.localeId;
      }
      // Fall back to same language prefix (e.g. any en_* for en_IN).
      final prefix = target.split('_').first;
      for (final l in locales) {
        if (l.localeId.toLowerCase().startsWith(prefix)) return l.localeId;
      }
    } catch (_) {}
    return wanted;
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  void dispose() => _speech.cancel();
}
