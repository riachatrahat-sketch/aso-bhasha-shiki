import '../../core/utils/json_helpers.dart';
import 'lesson.dart';

/// What the app sends when the learner submits an answer.
class AttemptRequest {
  const AttemptRequest({
    required this.lessonId,
    required this.activity,
    required this.index,
    this.answer,
    this.transcript,
    this.audioBase64,
  });

  final String lessonId;
  final Activity activity;
  final int index;

  /// Typed text (writing) or the chosen option (listening).
  final String? answer;

  /// Speech-to-text result (speaking, STT mode).
  final String? transcript;

  /// Base64 WAV, 16 kHz mono (speaking, Azure mode).
  final String? audioBase64;

  Map<String, dynamic> toMap() => {
        'lessonId': lessonId,
        'activity': activity.name,
        'index': index,
        if (answer != null) 'answer': answer,
        if (transcript != null) 'transcript': transcript,
        if (audioBase64 != null) 'audioBase64': audioBase64,
        // The server runs in UTC, so the app sends the learner's local date.
        'dayKey': dayKey(DateTime.now()),
      };
}

/// The outcome shown to the learner after one attempt.
class AttemptResult {
  const AttemptResult({
    required this.correct,
    required this.passed,
    required this.alreadyPassed,
    required this.delta,
    required this.questionPoints,
    required this.correctAnswer,
    required this.explanation,
    required this.lessonCompleted,
    this.heard,
    this.similarity,
    this.completeness,
    this.accuracy,
    this.pronScore,
    this.fluencyScore,
    this.missingWords = const [],
  });

  final bool correct;

  /// The question is now passed (true for a correct attempt and when it was
  /// already passed earlier).
  final bool passed;
  final bool alreadyPassed;

  /// Points changed by this attempt (+0.5, -1 or 0).
  final double delta;

  /// Net points of this question after the attempt.
  final double questionPoints;

  final String correctAnswer;
  final String explanation;
  final bool lessonCompleted;

  final String? heard;
  final double? similarity;
  final double? completeness;
  final double? accuracy;
  final double? pronScore;
  final double? fluencyScore;
  final List<String> missingWords;

  factory AttemptResult.fromMap(Map<String, dynamic> m) => AttemptResult(
        correct: m['correct'] == true,
        passed: m['passed'] == true,
        alreadyPassed: m['alreadyPassed'] == true,
        delta: asDouble(m['delta']),
        questionPoints: asDouble(m['questionPoints']),
        correctAnswer: (m['correctAnswer'] as String?) ?? '',
        explanation: (m['explanation'] as String?) ?? '',
        lessonCompleted: m['lessonCompleted'] == true,
        heard: m['heard'] as String?,
        similarity: (m['similarity'] as num?)?.toDouble(),
        completeness: (m['completeness'] as num?)?.toDouble(),
        accuracy: (m['accuracy'] as num?)?.toDouble(),
        pronScore: (m['pronScore'] as num?)?.toDouble(),
        fluencyScore: (m['fluencyScore'] as num?)?.toDouble(),
        missingWords: ((m['missingWords'] as List?) ?? const []).cast<String>(),
      );
}
