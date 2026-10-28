import '../../core/utils/json_helpers.dart';
import '../../domain/scoring/scoring_engine.dart';

/// Progress of one lesson: nine questions (3 activities x 3 questions).
class LessonProgress {
  const LessonProgress({
    required this.lessonId,
    required this.questions,
    required this.completed,
    this.completedAt,
  });

  factory LessonProgress.empty(String lessonId) =>
      LessonProgress(lessonId: lessonId, questions: const {}, completed: false);

  final String lessonId;

  /// Keyed by "<activity>_<index>", for example "speaking_0".
  final Map<String, QuestionProgress> questions;
  final bool completed;
  final DateTime? completedAt;

  factory LessonProgress.fromMap(String lessonId, Map<String, dynamic> m) {
    final raw = (m['questions'] as Map?) ?? const {};
    return LessonProgress(
      lessonId: lessonId,
      questions: {
        for (final e in raw.entries)
          e.key as String: QuestionProgress.fromMap(Map<String, dynamic>.from(e.value as Map)),
      },
      completed: m['completed'] == true,
      completedAt: parseDate(m['completedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'lessonId': lessonId,
        'questions': {for (final e in questions.entries) e.key: e.value.toMap()},
        'completed': completed,
        'completedAt': completedAt?.toIso8601String(),
      };

  LessonProgress copyWith({
    Map<String, QuestionProgress>? questions,
    bool? completed,
    DateTime? completedAt,
  }) =>
      LessonProgress(
        lessonId: lessonId,
        questions: questions ?? this.questions,
        completed: completed ?? this.completed,
        completedAt: completedAt ?? this.completedAt,
      );
}
