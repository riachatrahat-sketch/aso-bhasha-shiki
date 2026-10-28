import 'package:flutter_test/flutter_test.dart';
import 'package:lingobridge_ai/core/utils/text_similarity.dart';
import 'package:lingobridge_ai/domain/streak.dart';

void main() {
  group('StreakCalculator', () {
    final today = DateTime(2026, 3, 10);

    test('no activity means no streak', () {
      expect(StreakCalculator.current({}, today), 0);
    });

    test('counts consecutive days ending today', () {
      expect(StreakCalculator.current({'2026-03-10', '2026-03-09', '2026-03-08'}, today), 3);
    });

    test('stays alive when only yesterday is active', () {
      expect(StreakCalculator.current({'2026-03-09', '2026-03-08'}, today), 2);
    });

    test('a gap resets the streak', () {
      expect(StreakCalculator.current({'2026-03-10', '2026-03-08'}, today), 1);
      expect(StreakCalculator.current({'2026-03-07'}, today), 0);
    });

    test('works across a month boundary', () {
      expect(StreakCalculator.current({'2026-03-01', '2026-02-28', '2026-02-27'}, DateTime(2026, 3, 1)), 3);
    });
  });

  group('SpeechMatcher', () {
    test('exact speech passes with full completeness', () {
      final c = SpeechMatcher.compare(expected: 'Thank you', heard: 'thank you', language: 'en');
      expect(c.similarity, 1);
      expect(c.completeness, 1);
      expect(c.missing, isEmpty);
    });

    test('"tank you" looks similar but is incomplete', () {
      final c = SpeechMatcher.compare(expected: 'Thank you', heard: 'tank you', language: 'en');
      expect(c.similarity, greaterThanOrEqualTo(0.8));
      expect(c.completeness, 0.5);
      expect(c.missing, ['thank']);
    });

    test('silence scores zero', () {
      final c = SpeechMatcher.compare(expected: 'Hello', heard: '', language: 'en');
      expect(c.similarity, 0);
      expect(c.completeness, 0);
    });

    test('Japanese is compared per character', () {
      final c = SpeechMatcher.compare(expected: 'ありがとう', heard: 'ありがと', language: 'ja');
      expect(c.completeness, closeTo(0.8, 1e-9));
      expect(c.missing, ['う']);
    });

    test('alternatives are tried', () {
      final c = SpeechMatcher.compare(
        expected: 'すし',
        heard: '寿司',
        language: 'ja',
        alternatives: const ['寿司'],
      );
      expect(c.similarity, 1);
    });
  });

  test('levenshtein basics', () {
    expect(TextSimilarity.levenshtein('kitten'.runes.toList(), 'sitting'.runes.toList()), 3);
    expect(TextSimilarity.ratio('', ''), 1);
  });
}
