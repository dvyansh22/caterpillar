import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'speech_to_text_voice_service.dart';
import 'voice_service.dart';

/// Active speech-to-text engine. Default is the OS/browser engine
/// (works on web + Android); the native build can swap in an offline
/// sherpa-onnx service behind this same provider.
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final s = SpeechToTextVoiceService();
  ref.onDispose(s.dispose);
  return s;
});

/// Selected voice-log language (English / Hindi / Tamil).
class VoiceLanguageNotifier extends Notifier<VoiceLanguage> {
  @override
  VoiceLanguage build() => kVoiceLanguages.first;
  void set(VoiceLanguage l) => state = l;
}

final voiceLanguageProvider =
    NotifierProvider<VoiceLanguageNotifier, VoiceLanguage>(VoiceLanguageNotifier.new);
