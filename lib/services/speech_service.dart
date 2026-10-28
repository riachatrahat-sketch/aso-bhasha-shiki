import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum SpeechAvailability { ready, permissionDenied, unavailable }

/// Speech-to-text wrapper (speech_to_text package).
///
/// Gives the recognised words as text. It does NOT measure pronunciation.
class SpeechService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _initialised = false;
  String _lastWords = '';
  Completer<String>? _final;

  /// True while the recogniser is actively listening.
  final ValueNotifier<bool> isListening = ValueNotifier(false);

  Future<SpeechAvailability> init() async {
    if (_initialised) return SpeechAvailability.ready;
    final ok = await _stt.initialize(
      onStatus: (status) {
        isListening.value = status == 'listening';
      },
      onError: (_) {
        isListening.value = false;
      },
    );
    if (ok) {
      _initialised = true;
      return SpeechAvailability.ready;
    }
    final mic = await Permission.microphone.status;
    return (mic.isDenied || mic.isPermanentlyDenied)
        ? SpeechAvailability.permissionDenied
        : SpeechAvailability.unavailable;
  }

  /// Finds the recogniser locale that matches [wanted] (e.g. "ja_JP").
  /// Returns null when the phone has no such recogniser.
  Future<String?> resolveLocale(String wanted) async {
    String norm(String s) => s.replaceAll('-', '_').toLowerCase();
    final locales = await _stt.locales();
    for (final l in locales) {
      if (norm(l.localeId) == norm(wanted)) return l.localeId;
    }
    final lang = norm(wanted).split('_').first;
    for (final l in locales) {
      if (norm(l.localeId).startsWith('${lang}_')) return l.localeId;
    }
    return null;
  }

  Future<void> start({
    required String localeId,
    required void Function(String words) onPartial,
  }) async {
    _lastWords = '';
    _final = Completer<String>();
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) {
        _lastWords = r.recognizedWords;
        onPartial(_lastWords);
        final c = _final;
        if (r.finalResult && c != null && !c.isCompleted) c.complete(_lastWords);
      },
      localeId: localeId,
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
    );
  }

  /// Stops listening and returns the final recognised text.
  Future<String> stop() async {
    await _stt.stop();
    final c = _final;
    if (c == null) return _lastWords;
    return c.future.timeout(const Duration(seconds: 3), onTimeout: () => _lastWords);
  }

  Future<void> cancel() async {
    await _stt.cancel();
    isListening.value = false;
  }

  void dispose() {
    _stt.cancel();
    isListening.dispose();
  }
}
