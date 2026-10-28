/// Normalisation rules for typed and spoken answers.
///
/// Goal: forgive harmless differences, never forgive wrong spelling.
///
/// Applied to BOTH languages
///  1. Full-width ASCII (ＡＢＣ１２３！) becomes normal ASCII.
///  2. Curly quotes become straight quotes.
///  3. Runs of whitespace (including the ideographic space) collapse to one space.
///  4. Leading/trailing whitespace and edge punctuation are removed.
///
/// English only
///  5. Case is ignored ("hello" == "Hello").
///
/// Japanese only
///  6. All spaces are removed (speech recognisers insert them randomly).
///
/// NOT done on purpose (these would accept wrong answers)
///  - hiragana <-> katakana conversion ("すし" != "スシ")
///  - kanji <-> kana conversion (listed explicitly as `alternatives` per item)
///  - fixing misspelled letters or dropping the long vowel mark "ー"
///
/// Keep in sync with functions/src/normalize.ts.
class AnswerNormalizer {
  AnswerNormalizer._();

  static const _enEdge = '.,!?;:"\'';
  static const _jaEdge = '。、．，！？!?.,「」『』"\'';

  static String normalize(String input, {required String language}) {
    var s = _toHalfWidthAscii(input);
    s = s
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (language == 'ja') {
      s = s.replaceAll(' ', '');
      return _stripEdges(s, _jaEdge);
    }
    return _stripEdges(s.toLowerCase(), _enEdge).trim();
  }

  /// True when [input] equals [expected] or one of [alternatives] after
  /// normalisation. An empty answer never matches.
  static bool isMatch({
    required String input,
    required String expected,
    List<String> alternatives = const [],
    required String language,
  }) {
    final n = normalize(input, language: language);
    if (n.isEmpty) return false;
    for (final candidate in [expected, ...alternatives]) {
      if (normalize(candidate, language: language) == n) return true;
    }
    return false;
  }

  static String _toHalfWidthAscii(String s) => String.fromCharCodes(
        s.runes.map((r) => (r >= 0xFF01 && r <= 0xFF5E) ? r - 0xFEE0 : r),
      );

  static String _stripEdges(String s, String edgeChars) {
    final edge = edgeChars.runes.toSet();
    final runes = s.runes.toList();
    var start = 0;
    var end = runes.length;
    while (start < end && (edge.contains(runes[start]) || runes[start] == 0x20)) {
      start++;
    }
    while (end > start && (edge.contains(runes[end - 1]) || runes[end - 1] == 0x20)) {
      end--;
    }
    return String.fromCharCodes(runes.sublist(start, end));
  }
}
