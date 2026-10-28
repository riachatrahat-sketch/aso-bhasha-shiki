import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingobridge_ai/core/utils/answer_normalizer.dart';
import 'package:lingobridge_ai/data/catalog/lesson_catalog.dart';

/// Sanity checks for assets/content/lessons.json. These catch content mistakes
/// (a lesson with two items, a repeated word, an unanswerable question) before
/// a learner ever sees them.
void main() {
  late LessonCatalog catalog;

  setUpAll(() {
    final raw = File('assets/content/lessons.json').readAsStringSync();
    catalog = LessonCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  test('there are at least 3000 tasks (lessons x 9 questions)', () {
    expect(catalog.lessons.length * 9, greaterThanOrEqualTo(3000));
  });

  test('lesson ids are unique and every lesson has exactly three items', () {
    final ids = <String>{};
    for (final lesson in catalog.lessons) {
      expect(ids.add(lesson.id), isTrue, reason: 'duplicate id ${lesson.id}');
      expect(lesson.items, hasLength(3), reason: lesson.id);
    }
  });

  test('every lesson belongs to a known language and level', () {
    for (final lesson in catalog.lessons) {
      final language = catalog.language(lesson.language);
      expect(language, isNotNull, reason: lesson.id);
      expect(
        language!.levels.map((l) => l.id),
        contains(lesson.level),
        reason: lesson.id,
      );
    }
  });

  test('words and Bangla meanings are unique within a language', () {
    for (final language in catalog.languages) {
      final targets = <String>{};
      final meanings = <String>{};
      for (final lesson in catalog.lessonsFor(language.id)) {
        for (final item in lesson.items) {
          final key = AnswerNormalizer.normalize(item.target, language: language.id);
          expect(targets.add(key), isTrue, reason: 'repeated word ${item.target}');
          expect(meanings.add(item.meaningBn), isTrue,
              reason: 'repeated meaning ${item.meaningBn} (${item.target})');
        }
      }
    }
  });

  test('every item accepts its own target and alternatives as a typed answer', () {
    for (final lesson in catalog.lessons) {
      for (final item in lesson.items) {
        expect(
          AnswerNormalizer.isMatch(
            input: item.target,
            expected: item.target,
            alternatives: item.alternatives,
            language: lesson.language,
          ),
          isTrue,
          reason: item.target,
        );
        for (final alt in item.alternatives) {
          expect(
            AnswerNormalizer.isMatch(
              input: alt,
              expected: item.target,
              alternatives: item.alternatives,
              language: lesson.language,
            ),
            isTrue,
            reason: '${item.target} / $alt',
          );
        }
      }
    }
  });

  test('every listening question has four distinct options including the answer', () {
    for (final lesson in catalog.lessons) {
      for (var i = 0; i < 3; i++) {
        final q = catalog.listeningQuestion(lesson, i);
        expect(q.options, hasLength(4), reason: '${lesson.id} #$i');
        expect(q.options.toSet(), hasLength(4), reason: '${lesson.id} #$i');
        expect(q.options, contains(q.correct), reason: '${lesson.id} #$i');
      }
    }
  });
}
