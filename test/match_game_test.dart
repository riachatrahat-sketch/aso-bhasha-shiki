import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingobridge_ai/data/catalog/lesson_catalog.dart';
import 'package:lingobridge_ai/domain/match_game.dart';

void main() {
  late LessonCatalog catalog;

  setUpAll(() {
    final raw = File('assets/content/lessons.json').readAsStringSync();
    catalog = LessonCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  test('levels get harder: more pairs and less time per pair', () {
    expect(MatchRules.pairsFor(1), 3);
    expect(MatchRules.pairsFor(30), 8);
    for (var n = 2; n <= MatchRules.levelCount; n++) {
      expect(MatchRules.pairsFor(n), greaterThanOrEqualTo(MatchRules.pairsFor(n - 1)));
      final perPair = MatchRules.secondsFor(n) / MatchRules.pairsFor(n);
      final prevPerPair = MatchRules.secondsFor(n - 1) / MatchRules.pairsFor(n - 1);
      expect(perPair, lessThanOrEqualTo(prevPerPair));
    }
  });

  test('stars depend on mistakes', () {
    expect(MatchRules.starsFor(mistakes: 0, pairs: 4), 3);
    expect(MatchRules.starsFor(mistakes: 2, pairs: 4), 2);
    expect(MatchRules.starsFor(mistakes: 5, pairs: 4), 1);
  });

  test('every deck gives enough distinct words on every level', () {
    for (final language in catalog.languages) {
      for (final level in language.levels) {
        if (catalog.lessonsFor(language.id, levelId: level.id).isEmpty) continue;
        for (var n = 1; n <= MatchRules.levelCount; n++) {
          final words = MatchRules.wordsFor(
            catalog,
            languageId: language.id,
            levelId: level.id,
            level: n,
          );
          expect(words, hasLength(MatchRules.pairsFor(n)), reason: '${language.id}/${level.id} #$n');
          final mode = MatchRules.modeFor(n);
          expect(words.map((w) => MatchRules.rightLabel(mode, w)).toSet(), hasLength(words.length),
              reason: '${language.id}/${level.id} #$n');
          expect(words.map((w) => w.target).toSet(), hasLength(words.length));
        }
      }
    }
  });

  test('the same level always gives the same words', () {
    final a = MatchRules.wordsFor(catalog, languageId: 'en', levelId: 'ielts', level: 7);
    final b = MatchRules.wordsFor(catalog, languageId: 'en', levelId: 'ielts', level: 7);
    expect(a.map((w) => w.target).toList(), b.map((w) => w.target).toList());
  });
}
