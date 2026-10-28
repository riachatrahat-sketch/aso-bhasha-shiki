import '../data/catalog/lesson_catalog.dart';
import '../data/models/lesson.dart';
import '../data/models/lesson_progress.dart';
import '../data/models/user_data.dart';
import 'scoring/progression.dart';

/// Numbers for the Progress screen.
class ProgressInsights {
  ProgressInsights._();

  /// Passed questions divided by attempts for one activity, or null when the
  /// learner has not tried it yet. 1.0 means every attempt was right first time.
  static double? accuracy(Map<String, LessonProgress> progress, Activity activity) {
    var passed = 0;
    var attempts = 0;
    for (final p in progress.values) {
      passed += Progression.passedCount(p, activity);
      attempts += Progression.attemptsFor(p, activity);
    }
    return attempts == 0 ? null : passed / attempts;
  }

  /// The activity with the lowest accuracy, or null when nothing was attempted.
  static Activity? weakestActivity(Map<String, LessonProgress> progress) {
    Activity? weakest;
    double? lowest;
    for (final a in Activity.values) {
      final acc = accuracy(progress, a);
      if (acc == null) continue;
      if (lowest == null || acc < lowest) {
        lowest = acc;
        weakest = a;
      }
    }
    return weakest;
  }

  /// Up to [limit] lessons to practise: unfinished lessons in the weakest
  /// activity first, preferring the learner's preferred language.
  static List<({Lesson lesson, Activity activity})> recommendations(
    LessonCatalog catalog,
    Map<String, LessonProgress> progress,
    String preferredLanguage, {
    int limit = 3,
  }) {
    final weakest = weakestActivity(progress);
    final languages = [
      preferredLanguage,
      ...catalog.languages.map((l) => l.id).where((id) => id != preferredLanguage),
    ];
    final result = <({Lesson lesson, Activity activity})>[];

    for (final lang in languages) {
      for (final lesson in catalog.lessonsFor(lang)) {
        if (result.length >= limit) return result;
        final p = progress[lesson.id];
        if (weakest != null) {
          // Prefer lessons where the weak activity was started but not finished.
          if (!Progression.activityCompleted(p, weakest)) {
            result.add((lesson: lesson, activity: weakest));
          }
        } else if (!Progression.lessonCompleted(p)) {
          result.add((lesson: lesson, activity: Activity.speaking));
        }
      }
    }
    return result;
  }

  /// Passed questions for the last [days] days ending today, oldest first.
  static List<({String date, int passed})> lastDays(
    List<DailyActivity> daily,
    DateTime today, {
    int days = 7,
  }) {
    final byDate = {for (final d in daily) d.date: d.passed};
    final result = <({String date, int passed})>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = DateTime(today.year, today.month, today.day - i);
      final key = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      result.add((date: key, passed: byDate[key] ?? 0));
    }
    return result;
  }
}
