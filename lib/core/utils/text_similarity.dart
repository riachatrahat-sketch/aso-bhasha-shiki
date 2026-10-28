import 'dart:math' as math;

import 'answer_normalizer.dart';

/// Result of comparing what the user said with the target text.
///
/// IMPORTANT: this compares TEXT produced by a speech recogniser. It measures
/// whether the recogniser understood the learner, which is a useful proxy for
/// clear pronunciation, but it is not a phonetic score. Real pronunciation
/// scoring is done by the optional Azure mode on the server.
class SpeechComparison {
  const SpeechComparison({
    required this.similarity,
    required this.completeness,
    required this.accuracy,
    required this.missing,
    required this.heard,
  });

  /// 1 - editDistance / maxLength, in 0..1.
  final double similarity;

  /// Share of the target that was spoken (LCS / target length).
  final double completeness;

  /// Share of what was spoken that matches the target (LCS / heard length).
  final double accuracy;

  /// Target words (English) or characters (Japanese) that were not heard.
  final List<String> missing;

  final String heard;
}

class TextSimilarity {
  TextSimilarity._();

  static int levenshtein(List<int> a, List<int> b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      prev = cur;
    }
    return prev[b.length];
  }

  static double ratio(String a, String b) {
    final ra = a.runes.toList();
    final rb = b.runes.toList();
    final longest = math.max(ra.length, rb.length);
    if (longest == 0) return 1;
    return 1 - levenshtein(ra, rb) / longest;
  }

  static int lcsLength(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    var prev = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      for (var j = 1; j <= b.length; j++) {
        cur[j] = a[i - 1] == b[j - 1] ? prev[j - 1] + 1 : math.max(prev[j], cur[j - 1]);
      }
      prev = cur;
    }
    return prev[b.length];
  }
}

class SpeechMatcher {
  SpeechMatcher._();

  /// Compares [heard] with [expected] and every alternative spelling, and
  /// returns the best comparison (highest similarity).
  static SpeechComparison compare({
    required String expected,
    required String heard,
    required String language,
    List<String> alternatives = const [],
  }) {
    final normalizedHeard = AnswerNormalizer.normalize(heard, language: language);
    SpeechComparison? best;
    for (final candidate in [expected, ...alternatives]) {
      final c = _compareOne(
        AnswerNormalizer.normalize(candidate, language: language),
        normalizedHeard,
        language,
      );
      if (best == null || c.similarity > best.similarity) best = c;
    }
    return best!;
  }

  static SpeechComparison _compareOne(String expected, String heard, String language) {
    // English is compared word by word, Japanese character by character
    // because Japanese text has no spaces between words.
    List<String> units(String s) => language == 'ja'
        ? s.runes.map((r) => String.fromCharCode(r)).toList()
        : s.split(' ').where((w) => w.isNotEmpty).toList();

    final e = units(expected);
    final h = units(heard);
    final lcs = TextSimilarity.lcsLength(e, h);

    final remaining = List<String>.from(h);
    final missing = <String>[];
    for (final unit in e) {
      if (!remaining.remove(unit)) missing.add(unit);
    }

    return SpeechComparison(
      similarity: heard.isEmpty ? 0 : TextSimilarity.ratio(expected, heard),
      completeness: e.isEmpty ? 0 : lcs / e.length,
      accuracy: h.isEmpty ? 0 : lcs / h.length,
      missing: missing,
      heard: heard,
    );
  }
}
