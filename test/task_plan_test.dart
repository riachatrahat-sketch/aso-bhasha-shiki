import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingobridge_ai/core/utils/answer_normalizer.dart';
import 'package:lingobridge_ai/data/catalog/lesson_catalog.dart';
import 'package:lingobridge_ai/data/models/attempt.dart';
import 'package:lingobridge_ai/data/models/lesson.dart';
import 'package:lingobridge_ai/domain/attempt_evaluator.dart';

/// Checks the per-question task plan written by tools/build_lessons.py and the
/// way the evaluator uses it.
void main() {
  late LessonCatalog catalog;
  late AttemptEvaluator evaluator;

  setUpAll(() {
    final raw = File('assets/content/lessons.json').readAsStringSync();
    catalog = LessonCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    evaluator = AttemptEvaluator(catalog);
  });

  test('every lesson plans three questions for each activity', () {
    for (final lesson in catalog.lessons) {
      for (final activity in Activity.values) {
        final list = lesson.tasks[activity.name];
        expect(list, isNotNull, reason: '${lesson.id} ${activity.name}');
        expect(list, hasLength(3), reason: '${lesson.id} ${activity.name}');
        for (final spec in list!) {
          expect(spec.item, inInclusiveRange(0, 2), reason: lesson.id);
        }
      }
    }
  });

  test('task kinds belong to their activity', () {
    const speaking = {TaskKind.readAloud, TaskKind.translateSpeak, TaskKind.sentenceSpeak};
    const listening = {
      TaskKind.meaning,
      TaskKind.word,
      TaskKind.sentenceBlank,
      TaskKind.sentenceWord,
    };
    const writing = {
      TaskKind.dictation,
      TaskKind.translateType,
      TaskKind.cloze,
      TaskKind.unscramble,
      TaskKind.sentenceDictation,
    };
    for (final lesson in catalog.lessons) {
      for (final spec in lesson.tasks['speaking']!) {
        expect(speaking, contains(spec.kind), reason: lesson.id);
      }
      for (final spec in lesson.tasks['listening']!) {
        expect(listening, contains(spec.kind), reason: lesson.id);
      }
      for (final spec in lesson.tasks['writing']!) {
        expect(writing, contains(spec.kind), reason: lesson.id);
      }
    }
  });

  test('a kind is only planned when the item can support it', () {
    for (final lesson in catalog.lessons) {
      for (final entry in lesson.tasks.entries) {
        for (final spec in entry.value) {
          final item = lesson.items[spec.item];
          if (spec.kind == TaskKind.cloze ||
              spec.kind == TaskKind.sentenceBlank ||
              spec.kind == TaskKind.sentenceWord) {
            expect(item.cloze, isNotNull, reason: '${lesson.id} ${spec.kind}');
          }
          if (spec.kind == TaskKind.unscramble) {
            expect(lesson.language, 'en', reason: lesson.id);
            expect(item.sentence.split(' ').length, greaterThanOrEqualTo(3), reason: lesson.id);
          }
        }
      }
    }
  });

  test('speaking, listening and writing do not all use the same item at question 1', () {
    var differing = 0;
    for (final lesson in catalog.lessons) {
      final items = {
        for (final a in Activity.values) lesson.taskFor(a, 0).item,
      };
      if (items.length == 3) differing++;
    }
    expect(differing, catalog.lessons.length);
  });

  test('lessons get harder: tiers never fall inside a level and reach the top', () {
    for (final language in catalog.languages) {
      for (final level in language.levels) {
        final lessons = catalog.lessonsFor(language.id, levelId: level.id);
        for (var i = 1; i < lessons.length; i++) {
          expect(lessons[i].tier, greaterThanOrEqualTo(lessons[i - 1].tier),
              reason: '${level.id} lesson ${i + 1}');
        }
      }
    }
    expect(catalog.lessons.map((l) => l.tier).reduce((a, b) => a > b ? a : b), 5);
  });

  test('the correct answer of every planned question is accepted by the evaluator', () {
    for (final lesson in catalog.lessons) {
      for (final activity in Activity.values) {
        for (var i = 0; i < 3; i++) {
          final expected = AttemptEvaluator.expectedAnswer(catalog, lesson, activity, i);
          final req = AttemptRequest(
            lessonId: lesson.id,
            activity: activity,
            index: i,
            answer: activity == Activity.speaking ? null : expected,
            transcript: activity == Activity.speaking ? expected : null,
          );
          final result = evaluator.evaluate(lesson, req);
          expect(result.correct, isTrue, reason: '${lesson.id} ${activity.name} #$i');
        }
      }
    }
  });

  test('a sentence typed without commas is still accepted', () {
    expect(
      AnswerNormalizer.isLooseMatch(
        input: 'hello how are you',
        expected: 'Hello, how are you?',
        language: 'en',
      ),
      isTrue,
    );
    expect(
      AnswerNormalizer.isLooseMatch(
        input: 'how hello are you',
        expected: 'Hello, how are you?',
        language: 'en',
      ),
      isFalse,
    );
  });

  test('a wrong sentence fails sentence dictation', () {
    for (final lesson in catalog.lessons) {
      for (var i = 0; i < 3; i++) {
        final spec = lesson.taskFor(Activity.writing, i);
        if (spec.kind != TaskKind.sentenceDictation) continue;
        final result = evaluator.evaluate(
          lesson,
          AttemptRequest(lessonId: lesson.id, activity: Activity.writing, index: i, answer: 'x'),
        );
        expect(result.correct, isFalse);
        return;
      }
    }
    fail('no sentenceDictation question found');
  });
}
