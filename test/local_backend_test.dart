import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingobridge_ai/core/utils/json_helpers.dart';
import 'package:lingobridge_ai/data/backend/local_backend.dart';
import 'package:lingobridge_ai/data/catalog/lesson_catalog.dart';
import 'package:lingobridge_ai/data/models/attempt.dart';
import 'package:lingobridge_ai/data/models/lesson.dart';
import 'package:lingobridge_ai/domain/scoring/progression.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Integration-style tests of the whole scoring flow (evaluate, score, unlock,
/// persist) using the local backend and the real lesson file.
void main() {
  late LessonCatalog catalog;
  late SharedPreferences prefs;
  late LocalBackend backend;
  late Lesson lesson;
  const uid = 'user1';

  LocalBackend makeBackend() => LocalBackend(
        prefs: prefs,
        catalog: catalog,
        clock: () => DateTime(2026, 1, 15, 10),
      );

  AttemptRequest writing(int i, String answer) => AttemptRequest(
        lessonId: lesson.id,
        activity: Activity.writing,
        index: i,
        answer: answer,
      );

  Future<double> total() async => (await backend.watchStats(uid).first).totalPoints;

  setUpAll(() {
    final raw = File('assets/content/lessons.json').readAsStringSync();
    catalog = LessonCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    lesson = catalog.lessonById('en_beginner_01')!;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    backend = makeBackend();
  });

  test('a correct answer awards 0.5 and the same question cannot award again', () async {
    final first = await backend.submit(uid, writing(0, 'hello'));
    expect(first.passed, isTrue);
    expect(first.delta, 0.5);

    final again = await backend.submit(uid, writing(0, 'hello'));
    expect(again.alreadyPassed, isTrue);
    expect(again.delta, 0);
    expect(await total(), 0.5);
  });

  test('duplicate prevention survives an app restart', () async {
    await backend.submit(uid, writing(0, 'Hello'));
    final restarted = makeBackend(); // same stored data, new instance
    final again = await restarted.submit(uid, writing(0, 'Hello'));
    expect(again.alreadyPassed, isTrue);
    expect(again.delta, 0);
    expect((await restarted.watchStats(uid).first).totalPoints, 0.5);
  });

  test('a wrong answer costs 1 point once; retries add no extra penalty', () async {
    final first = await backend.submit(uid, writing(0, 'Helo'));
    expect(first.passed, isFalse);
    expect(first.delta, -1);
    expect(first.correctAnswer, 'Hello');

    final second = await backend.submit(uid, writing(0, 'Hllo'));
    expect(second.delta, 0);
    expect(await total(), -1);

    final right = await backend.submit(uid, writing(0, 'Hello'));
    expect(right.passed, isTrue);
    expect(await total(), -0.5);
  });

  test('the next question stays locked until the current one is passed', () async {
    expect(
      () => backend.submit(uid, writing(1, 'Good morning')),
      throwsA(isA<AppException>()),
    );

    await backend.submit(uid, writing(0, 'Helo')); // wrong
    expect(
      () => backend.submit(uid, writing(1, 'Good morning')),
      throwsA(isA<AppException>()),
    );

    await backend.submit(uid, writing(0, 'Hello')); // now passed
    final next = await backend.submit(uid, writing(1, 'Good morning'));
    expect(next.passed, isTrue);
  });

  test('wrong answers are stored as mistakes with the correct answer', () async {
    await backend.submit(uid, writing(0, 'Helo'));
    final mistakes = await backend.watchMistakes(uid).first;
    expect(mistakes, hasLength(1));
    expect(mistakes.first.expected, 'Hello');
    expect(mistakes.first.given, 'Helo');
    expect(mistakes.first.activity, Activity.writing);
  });

  test('passed questions are counted for the day', () async {
    await backend.submit(uid, writing(0, 'Hello'));
    await backend.submit(uid, writing(1, 'Good morning'));
    final daily = await backend.watchDaily(uid).first;
    expect(daily, hasLength(1));
    expect(daily.first.date, '2026-01-15');
    expect(daily.first.passed, 2);
  });

  test('passing all nine questions completes the lesson with 4.5 points', () async {
    for (var i = 0; i < 3; i++) {
      final item = lesson.items[i];
      final r1 = await backend.submit(
        uid,
        AttemptRequest(
          lessonId: lesson.id,
          activity: Activity.speaking,
          index: i,
          transcript: item.target,
        ),
      );
      expect(r1.passed, isTrue, reason: 'speaking $i');

      final q = catalog.listeningQuestion(lesson, i);
      final r2 = await backend.submit(
        uid,
        AttemptRequest(
          lessonId: lesson.id,
          activity: Activity.listening,
          index: i,
          answer: q.correct,
        ),
      );
      expect(r2.passed, isTrue, reason: 'listening $i');

      final r3 = await backend.submit(uid, writing(i, item.target));
      expect(r3.passed, isTrue, reason: 'writing $i');
      if (i == 2) expect(r3.lessonCompleted, isTrue);
    }

    final progress = (await backend.watchProgress(uid).first)[lesson.id];
    expect(Progression.lessonCompleted(progress), isTrue);
    expect(progress!.completed, isTrue);
    expect(progress.completedAt, isNotNull);
    expect(Progression.lessonPoints(progress), 4.5);
    expect(await total(), 4.5);
  });

  test('a wrong listening choice is rejected and explained', () async {
    final q = catalog.listeningQuestion(lesson, 0);
    final wrong = q.options.firstWhere((o) => o != q.correct);
    final r = await backend.submit(
      uid,
      AttemptRequest(
        lessonId: lesson.id,
        activity: Activity.listening,
        index: 0,
        answer: wrong,
      ),
    );
    expect(r.passed, isFalse);
    expect(r.correctAnswer, q.correct);
    expect(r.explanation, isNotEmpty);
  });

  test('speaking: a missed word fails even when the letters are similar', () async {
    final thankYou = catalog.lessonById('en_beginner_01')!;
    final r = await backend.submit(
      uid,
      AttemptRequest(
        lessonId: thankYou.id,
        activity: Activity.speaking,
        index: 0,
        transcript: 'hallo',
      ),
    );
    expect(r.passed, isFalse);
    expect(r.completeness, isNotNull);
  });

  test('an unknown lesson is rejected', () async {
    expect(
      () => backend.submit(
        uid,
        const AttemptRequest(lessonId: 'nope', activity: Activity.writing, index: 0, answer: 'x'),
      ),
      throwsA(isA<AppException>()),
    );
  });

  test('deleting all data resets progress', () async {
    await backend.submit(uid, writing(0, 'Hello'));
    await backend.deleteAllData(uid);
    expect(await total(), 0);
    expect(await backend.watchProgress(uid).first, isEmpty);
  });
}
