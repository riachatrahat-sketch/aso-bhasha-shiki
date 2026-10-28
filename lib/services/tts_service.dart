import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech for reference audio. Uses the voices installed on the phone,
/// so an offline Japanese or English voice may need to be downloaded in the
/// device's system settings (Text-to-speech output).
class TtsService {
  final FlutterTts _tts = FlutterTts();

  /// Speaks [text]. Returns false when the language voice is unavailable.
  Future<bool> speak(String text, {required String locale, bool slow = false}) async {
    try {
      final available = await _tts.isLanguageAvailable(locale);
      // Android returns bool, iOS returns 1/0.
      final ok = available == true || available == 1;
      if (!ok) return false;
      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(slow ? 0.3 : 0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.stop();
      await _tts.speak(text);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
