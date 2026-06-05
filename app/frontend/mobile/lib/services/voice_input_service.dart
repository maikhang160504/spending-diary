import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Ghi âm giọng nói cục bộ (STT) — chuyển thành văn bản gửi chat NLU.
class VoiceInputService {
  VoiceInputService._();
  static final VoiceInputService instance = VoiceInputService._();

  final SpeechToText _stt = SpeechToText();
  bool _ready = false;
  bool? _deviceSupported;

  /// Kiểm tra thiết bị có STT (tránh lỗi recognizerNotAvailable trên emulator).
  Future<bool> checkAvailability() async {
    if (_deviceSupported != null) return _deviceSupported!;
    try {
      _deviceSupported = await _stt.initialize(
        onStatus: (_) {},
        onError: (e) => debugPrint('STT error: $e'),
      );
      _ready = _deviceSupported == true;
      if (_deviceSupported == true) return true;
    } catch (e) {
      debugPrint('STT init failed: $e');
    }
    _deviceSupported = false;
    _ready = false;
    return false;
  }

  Future<bool> ensureReady() async {
    if (_deviceSupported == false) return false;
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return false;
    if (_ready) return true;
    return checkAvailability();
  }

  bool get isListening => _stt.isListening;

  Future<void> startListening({
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    String localeId = 'vi_VN',
  }) async {
    if (!await ensureReady()) {
      throw StateError('Speech recognition không khả dụng trên thiết bị này');
    }
    if (_stt.isListening) await _stt.stop();

    var lastFinal = '';
    await _stt.listen(
      onResult: (result) {
        final text = result.recognizedWords.trim();
        if (text.isEmpty) return;
        if (result.finalResult) {
          if (text != lastFinal) {
            lastFinal = text;
            onFinal(text);
          }
        } else {
          onPartial(text);
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  Future<void> stop() async {
    if (_stt.isListening) await _stt.stop();
  }

  Future<void> cancel() async {
    if (_stt.isListening) await _stt.cancel();
  }
}
