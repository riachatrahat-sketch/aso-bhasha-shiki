import 'package:flutter_test/flutter_test.dart';
import 'package:lingobridge_ai/data/models/lesson.dart';
import 'package:lingobridge_ai/data/models/lesson_progress.dart';
import 'package:lingobridge_ai/domain/scoring/progression.dart';
import 'package:lingobridge_ai/domain/scoring/scoring_engine.dart';

QuestionProgress _passed() => const QuestionProgress(
      status: QuestionStatus.passed,
      attempts: 1,
      wrongAttempts: 0,
      penaltiesApplied: 0,
      points: 0.5,
    );

QuestionProgress _failedTwice() => const QuestionProgress(
      status: QuestionStatus.open,
      attempts: 2,
      wrongAttempts: 2,
      penaltiesApplied: 1,
      points: -1,
    );

LessonProgress _lesson(Map<String, QuestionProgress> q, {bool completed = false}) =>
    LessonProgress(lessonId: 'l1', questions: q, completed: completed);

void main() {
  group('question unlocking', () {
    test('only the first question is open at the start', () {
      expect(Progression.currentIndex(null, Activity.speaking), 0);
      expect(Progression.isUnlocked(null, Activity.speaking, 0), isTrue);
      expect(Progression.isUnlocked(null, Activity.speaking, 1), isFalse);
      expect(Progression.isUnlocked(null, Activity.speaking, 2), isFalse);
    });

    test('passing a question unlocks exactly the next one', () {
      final p = _lesson({'speaking_0': _passed()});
      expect(Progression.currentIndex(p, Activity.speaking), 1);
      expect(Progression.isUnlocked(p, Activity.speaking, 1), isTrue);
      expect(Progression.isUnlocked(p, Activity.speaking, 2), isFalse);
    });

    test('a failed question does NOT unlock the next one', () {
      final p = _lesson({'listening_0': _failedTwice()});
      expect(Progression.currentIndex(p, Activity.listening), 0);
      expect(Progression.isUnlocked(p, Activity.listening, 1), isFalse);
    });

    test('questions cannot be skipped', () {
      final p = _lesson({'writing_0': _passed(), 'writing_2': _passed()});
      expect(Progression.isUnlocked(p, Activity.writing, 2), isFalse);
      expect(Progression.currentIndex(p, Activity.writing), 1);
    });

    test('activities are independent', () {
      final p = _lesson({'speaking_0': _passed()});
      expect(Progression.isUnlocked(p, Activity.listening, 1), isFalse);
      expect(Progression.isUnlocked(p, Activity.listening, 0), isTrue);
    });

    test('out-of-range questions are never unlocked', () {
      expect(Progression.isUnlocked(null, Activity.speaking, -1), isFalse);
      expect(Progression.isUnlocked(null, Activity.speaking, 3), isFalse);
    });
  });

  group('lesson completion', () {
    Map<String, QuestionProgress> all() => {
          for (final a in Activity.values)
            for (var i = 0; i < 3; i++) '${a.name}_$i': _passed(),
        };

    test('an activity completes after three passed questions', () {
      final p = _lesson({for (var i = 0; i < 3; i++) 'speaking_$i': _passed()});
      expect(Progression.activityCompleted(p, Activity.speaking), isTrue);
      expect(Progression.activityCompleted(p, Activity.writing), isFalse);
      expect(Progression.currentIndex(p, Activity.speaking), 3);
    });

    test('a lesson completes only when all nine questions are passed', () {
      expect(Progression.lessonCompleted(_lesson(all())), isTrue);
      final missing = all()..remove('writing_2');
      expect(Progression.lessonCompleted(_lesson(missing)), isFalse);
      expect(Progression.lessonCompleted(null), isFalse);
    });

    test('lesson points add up all questions', () {
      expect(Progression.lessonPoints(_lesson(all())), 4.5);
      expect(Progression.activityPoints(_lesson(all()), Activity.listening), 1.5);
    });
  });
}
