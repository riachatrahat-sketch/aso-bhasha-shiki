import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records the learner's voice as 16 kHz mono WAV, the format Azure
/// Pronunciation Assessment expects. The file is read into memory and deleted
/// immediately, so no recording is kept on the phone.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  /// Returns false when the microphone permission is missing.
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/attempt_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: path,
    );
    return true;
  }

  /// Stops recording and returns the audio as base64, or null if nothing was recorded.
  Future<String?> stopAsBase64() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    final file = File(path);
    try {
      final bytes = await file.readAsBytes();
      return bytes.isEmpty ? null : base64Encode(bytes);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> cancel() async {
    final path = await _recorder.stop();
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
  }

  Future<void> dispose() => _recorder.dispose();
}
