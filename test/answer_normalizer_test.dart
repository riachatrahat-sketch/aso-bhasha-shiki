import 'package:flutter_test/flutter_test.dart';
import 'package:lingobridge_ai/core/utils/answer_normalizer.dart';

/// Test vectors are identical to functions/test/normalize.test.ts.
void main() {
  group('English', () {
    test('ignores case, spacing, edge punctuation and full-width characters', () {
      expect(AnswerNormalizer.normalize('  Hello  ', language: 'en'), 'hello');
      expect(AnswerNormalizer.normalize('How are you?', language: 'en'), 'how are you');
      expect(AnswerNormalizer.normalize('Good   morning.', language: 'en'), 'good morning');
      expect(AnswerNormalizer.normalize('ＨＥＬＬＯ！', language: 'en'), 'hello');
      expect(AnswerNormalizer.normalize('It’s', language: 'en'), "it's");
    });

    test('does NOT accept wrong spelling', () {
      expect(AnswerNormalizer.isMatch(input: 'Helo', expected: 'Hello', language: 'en'), isFalse);
      expect(
        AnswerNormalizer.isMatch(input: 'Good mornin', expected: 'Good morning', language: 'en'),
        isFalse,
      );
      expect(AnswerNormalizer.isMatch(input: '', expected: 'Hello', language: 'en'), isFalse);
    });

    test('accepts leading and trailing spaces', () {
      expect(
        AnswerNormalizer.isMatch(input: '   thank you   ', expected: 'Thank you', language: 'en'),
        isTrue,
      );
    });
  });

  group('Japanese', () {
    test('ignores spaces and trailing punctuation', () {
      expect(AnswerNormalizer.normalize('おはよう ございます。', language: 'ja'), 'おはようございます');
      expect(AnswerNormalizer.normalize('　すみません！', language: 'ja'), 'すみません');
    });

    test('does NOT treat hiragana and katakana as the same', () {
      expect(AnswerNormalizer.isMatch(input: 'スシ', expected: 'すし', language: 'ja'), isFalse);
      expect(AnswerNormalizer.isMatch(input: 'すし', expected: 'すし', language: 'ja'), isTrue);
    });

    test('accepts kanji only when listed as an alternative', () {
      expect(AnswerNormalizer.isMatch(input: '寿司', expected: 'すし', language: 'ja'), isFalse);
      expect(
        AnswerNormalizer.isMatch(
          input: '寿司',
          expected: 'すし',
          alternatives: const ['寿司'],
          language: 'ja',
        ),
        isTrue,
      );
    });

    test('keeps the long vowel mark', () {
      expect(AnswerNormalizer.isMatch(input: 'コヒ', expected: 'コーヒー', language: 'ja'), isFalse);
      expect(AnswerNormalizer.isMatch(input: 'コーヒー', expected: 'コーヒー', language: 'ja'), isTrue);
    });
  });
}
