/// Build-time configuration, passed with --dart-define.
///
///   flutter run --dart-define=BACKEND=local
///   flutter run --dart-define=PRONUNCIATION_MODE=azure
///
/// BACKEND
///   firebase (default): answers are checked and scores written by the
///                       `submitAttempt` Cloud Function (trusted).
///   local:              the same logic runs on the device and progress is kept
///                       in SharedPreferences. Needs no Blaze billing, but is
///                       NOT tamper-proof. Use it for demos and development.
///
/// PRONUNCIATION_MODE
///   stt (default): speech_to_text transcript is compared with the target.
///   azure:         the recorded WAV is sent to the Cloud Function, which calls
///                  Azure Pronunciation Assessment (needs an Azure Speech key).
enum BackendMode { firebase, local }

enum PronunciationMode { speechToText, azure }

class AppConfig {
  AppConfig._();

  static const _backend = String.fromEnvironment('BACKEND', defaultValue: 'firebase');
  static const _pronunciation =
      String.fromEnvironment('PRONUNCIATION_MODE', defaultValue: 'stt');

  static const functionsRegion =
      String.fromEnvironment('FUNCTIONS_REGION', defaultValue: 'us-central1');

  static BackendMode get backend =>
      _backend == 'local' ? BackendMode.local : BackendMode.firebase;

  /// Azure scoring needs the server, so local mode always uses speech-to-text.
  static PronunciationMode get pronunciation =>
      (_pronunciation == 'azure' && backend == BackendMode.firebase)
          ? PronunciationMode.azure
          : PronunciationMode.speechToText;

  /// Minimum text similarity (0..1) for a spoken answer to pass in STT mode.
  static const double speakingPassSimilarity = 0.8;
}
