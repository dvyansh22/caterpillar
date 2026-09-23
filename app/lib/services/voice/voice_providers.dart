import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sherpa_voice_service.dart';
import 'speech_to_text_voice_service.dart';
import 'voice_service.dart';

/// Active speech-to-text engine: offline sherpa-onnx (Whisper) on the phone,
/// the browser Web Speech API on web. Both sit behind [VoiceService].
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final VoiceService s = kIsWeb ? SpeechToTextVoiceService() : SherpaVoiceService();
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
