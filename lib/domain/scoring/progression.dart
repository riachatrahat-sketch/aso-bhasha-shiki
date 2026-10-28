import '../../data/models/lesson.dart';
import '../../data/models/lesson_progress.dart';
import 'scoring_engine.dart';

/// Question unlocking and lesson completion rules.
///
/// Within an activity the questions are strictly ordered: question i can only
/// be attempted once questions 0..i-1 are passed. A failed question never
/// unlocks the next one. Activities are independent of each other.
class Progression {
  Progression._();

  static const questionsPerActivity = 3;
  static const questionsPerLesson = questionsPerActivity * 3;

  static String key(Activity a, int index) => '${a.name}_$index';

  static QuestionProgress questionOf(LessonProgress? p, Activity a, int index) =>
      p?.questions[key(a, index)] ?? const QuestionProgress.initial();

  static bool isPassed(LessonProgress? p, Activity a, int index) =>
      questionOf(p, a, index).passed;

  /// Index of the first question that is not passed yet; equals
  /// [questionsPerActivity] when the activity is finished.
  static int currentIndex(LessonProgress? p, Activity a) {
    for (var i = 0; i < questionsPerActivity; i++) {
      if (!isPassed(p, a, i)) return i;
    }
    return questionsPerActivity;
  }

  static bool isUnlocked(LessonProgress? p, Activity a, int index) {
    if (index < 0 || index >= questionsPerActivity) return false;
    for (var i = 0; i < index; i++) {
      if (!isPassed(p, a, i)) return false;
    }
    return true;
  }

  static int passedCount(LessonProgress? p, Activity a) =>
      [for (var i = 0; i < questionsPerActivity; i++) isPassed(p, a, i)]
          .where((x) => x)
          .length;

  static bool activityCompleted(LessonProgress? p, Activity a) =>
      passedCount(p, a) == questionsPerActivity;

  static bool lessonCompleted(LessonProgress? p) =>
      Activity.values.every((a) => activityCompleted(p, a));

  static double activityPoints(LessonProgress? p, Activity a) => [
        for (var i = 0; i < questionsPerActivity; i++) questionOf(p, a, i).points,
      ].fold(0.0, (sum, v) => sum + v);

  static double lessonPoints(LessonProgress? p) =>
      Activity.values.fold(0.0, (sum, a) => sum + activityPoints(p, a));

  static int attemptsFor(LessonProgress? p, Activity a) => [
        for (var i = 0; i < questionsPerActivity; i++) questionOf(p, a, i).attempts,
      ].fold(0, (sum, v) => sum + v);
}
