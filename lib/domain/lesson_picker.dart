import '../core/utils/json_helpers.dart';
import '../data/catalog/lesson_catalog.dart';
import '../data/models/lesson.dart';
import '../data/models/lesson_progress.dart';
import 'scoring/progression.dart';

typedef Totals = ({int passed, int total});

/// Chooses which lesson to suggest next. Pure functions, easy to test.
class LessonPicker {
  LessonPicker._();

  /// Questions passed in one lesson (0..9).
  static int passedInLesson(LessonProgress? p) =>
      Activity.values.fold(0, (sum, a) => sum + Progression.passedCount(p, a));

  /// First lesson of [language] whose [activity] is not finished yet.
  static Lesson? nextForActivity(
    LessonCatalog catalog,
    Map<String, LessonProgress> progress,
    String language,
    Activity activity,
  ) {
    for (final l in catalog.lessonsFor(language)) {
      if (!Progression.activityCompleted(progress[l.id], activity)) return l;
    }
    return null;
  }

  /// A started-but-unfinished lesson, otherwise the first unfinished lesson.
  static Lesson? continueLesson(
    LessonCatalog catalog,
    Map<String, LessonProgress> progress,
    String language,
  ) {
    final lessons = catalog.lessonsFor(language);
    Lesson? firstUnfinished;
    for (final l in lessons) {
      final p = progress[l.id];
      if (Progression.lessonCompleted(p)) continue;
      firstUnfinished ??= l;
      if (passedInLesson(p) > 0) return l;
    }
    return firstUnfinished;
  }

  /// One unfinished lesson per day, the same all day, different the next day.
  static Lesson? dailyChallenge(
    LessonCatalog catalog,
    Map<String, LessonProgress> progress,
    String language,
    DateTime today,
  ) {
    final open = catalog
        .lessonsFor(language)
        .where((l) => !Progression.lessonCompleted(progress[l.id]))
        .toList();
    if (open.isEmpty) return null;
    return open[stableHash(dayKey(today)) % open.length];
  }

  static Totals activityTotals(
    LessonCatalog catalog,
    Map<String, LessonProgress> progress,
    String language,
    Activity activity,
  ) {
    final lessons = catalog.lessonsFor(language);
    final passed = lessons.fold(0, (s, l) => s + Progression.passedCount(progress[l.id], activity));
    return (passed: passed, total: lessons.length * Progression.questionsPerActivity);
  }

  static Totals languageTotals(
    LessonCatalog catalog,
    Map<String, LessonProgress> progress,
    String language, {
    String? levelId,
  }) {
    final lessons = catalog.lessonsFor(language, levelId: levelId);
    final passed = lessons.fold(0, (s, l) => s + passedInLesson(progress[l.id]));
    return (passed: passed, total: lessons.length * Progression.questionsPerLesson);
  }
}
