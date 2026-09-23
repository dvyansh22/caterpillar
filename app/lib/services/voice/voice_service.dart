/// Voice (speech-to-text) abstraction so the UI is identical for the browser/OS
/// engine now and an offline on-device engine (sherpa-onnx / Whisper) in the
/// native build. Same swappable pattern as AuthService/DataRepository.
library;

/// A supported voice-log language and its speech-recognition locale id.
class VoiceLanguage {
  const VoiceLanguage(this.label, this.localeId);
  final String label; // shown in the picker
  final String localeId; // e.g. en_IN / hi_IN / ta_IN
}

/// English, Hindi, Tamil.
const kVoiceLanguages = <VoiceLanguage>[
  VoiceLanguage('English', 'en_IN'),
  VoiceLanguage('हिन्दी', 'hi_IN'),
  VoiceLanguage('தமிழ்', 'ta_IN'),
];

abstract class VoiceService {
  /// Prepare the engine (offline engines download their model on first run;
  /// [onProgress] reports 0..1). Returns availability.
  Future<bool> init({void Function(double progress)? onProgress});

  bool get isAvailable;

  /// Begin listening in [localeId]. [onResult] is called with interim results and
  /// once more with [isFinal] = true. [onError] reports failures.
  Future<void> listen({
    required String localeId,
    required void Function(String text, bool isFinal) onResult,
    void Function(String message)? onError,
  });

  /// Stop listening and finalise the current result.
  Future<void> stop();

  void dispose();
}
