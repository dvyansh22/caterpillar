import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'voice_service.dart';

/// Offline, on-device speech-to-text via sherpa-onnx + Whisper (multilingual:
/// English/Hindi/Tamil auto-detected). Works with no network once the model is
/// downloaded on first run. Record-then-transcribe (not streaming).
class SherpaVoiceService implements VoiceService {
  // Whisper "tiny" (multilingual: en/hi/ta) rather than "base": ~103 MB vs ~153 MB
  // and far lighter to decode, so the on-device transcribe doesn't spike memory
  // and get the app OOM-killed mid-decode on mid-range phones.
  static const _baseUrl =
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main';
  // filename -> approx bytes (for download progress)
  static const _files = <String, double>{
    'tiny-encoder.int8.onnx': 12.9e6,
    'tiny-decoder.int8.onnx': 89.9e6,
    'tiny-tokens.txt': 0.8e6,
  };

  sherpa.OfflineRecognizer? _recognizer;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final BytesBuilder _buf = BytesBuilder(copy: false);
  bool _available = false;
  bool _recording = false;
  void Function(String text, bool isFinal)? _onResult;
  void Function(String message)? _onError;

  @override
  bool get isAvailable => _available;

  Future<Directory> _modelDir() async {
    final dir = await getApplicationSupportDirectory();
    final md = Directory('${dir.path}/whisper-tiny');
    if (!md.existsSync()) md.createSync(recursive: true);
    return md;
  }

  @override
  Future<bool> init({void Function(double progress)? onProgress}) async {
    if (_available) return true;
    try {
      sherpa.initBindings();
      final md = await _modelDir();
      final dio = Dio();
      final grandTotal = _files.values.reduce((a, b) => a + b);
      double done = 0;
      for (final entry in _files.entries) {
        final path = '${md.path}/${entry.key}';
        final f = File(path);
        if (f.existsSync() && f.lengthSync() > 1000) {
          done += entry.value;
          onProgress?.call(done / grandTotal);
          continue;
        }
        await dio.download(
          '$_baseUrl/${entry.key}',
          path,
          onReceiveProgress: (r, _) => onProgress?.call((done + r) / grandTotal),
        );
        done += entry.value;
        onProgress?.call(done / grandTotal);
      }
      final config = sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: '${md.path}/tiny-encoder.int8.onnx',
            decoder: '${md.path}/tiny-decoder.int8.onnx',
            task: 'transcribe', // language auto-detected (en/hi/ta)
          ),
          tokens: '${md.path}/tiny-tokens.txt',
          numThreads: 2,
          debug: false,
        ),
      );
      _recognizer = sherpa.OfflineRecognizer(config);
      _available = true;
      return true;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  @override
  Future<void> listen({
    required String localeId, // ignored: Whisper auto-detects the language
    required void Function(String text, bool isFinal) onResult,
    void Function(String message)? onError,
  }) async {
    _onResult = onResult;
    _onError = onError;
    if (!_available) {
      final ok = await init();
      if (!ok) {
        onError?.call('Offline voice model not ready.');
        return;
      }
    }
    if (!await _recorder.hasPermission()) {
      onError?.call('Microphone permission denied.');
      return;
    }
    _buf.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1),
    );
    _recording = true;
    _sub = stream.listen(_buf.add);
  }

  @override
  Future<void> stop() async {
    if (!_recording) return;
    _recording = false;
    await _recorder.stop();
    await _sub?.cancel();
    _sub = null;
    final samples = _pcm16ToFloat(_buf.toBytes());
    final rec = _recognizer;
    // Guard the native decoder: handing Whisper empty/very short audio (a fast
    // double-tap, or a device that delivered no PCM) reads out of bounds in the
    // feature extractor and takes the whole app down with a native crash that a
    // Dart try/catch cannot intercept. Require ~0.4 s (6400 samples @ 16 kHz).
    if (rec == null || samples.length < 6400) {
      _onError?.call('Didn\'t catch that. Hold the mic and speak.');
      return;
    }
    try {
      final s = rec.createStream();
      s.acceptWaveform(samples: samples, sampleRate: 16000);
      rec.decode(s);
      final text = rec.getResult(s).text;
      s.free();
      _onResult?.call(text.trim(), true);
    } catch (e) {
      _onError?.call('Could not transcribe audio.');
    }
  }

  Float32List _pcm16ToFloat(Uint8List bytes) {
    final n = bytes.length ~/ 2;
    final out = Float32List(n);
    final bd = ByteData.sublistView(bytes);
    for (var i = 0; i < n; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.dispose();
    _recognizer?.free();
  }
}
