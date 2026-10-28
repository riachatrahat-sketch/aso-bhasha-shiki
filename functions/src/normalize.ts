/**
 * Answer normalisation. Mirror of lib/core/utils/answer_normalizer.dart.
 * Keep both files in sync; the test vectors in test/normalize.test.ts match
 * the Dart tests.
 *
 * Forgives: case (English), spacing, edge punctuation, full-width ASCII.
 * Does NOT forgive: wrong spelling, hiragana vs katakana, kanji vs kana.
 */
const EN_EDGE = new Set([...`.,!?;:"'`].map((c) => c.codePointAt(0)!));
const JA_EDGE = new Set([...`。、．，！？!?.,「」『』"'`].map((c) => c.codePointAt(0)!));

function toHalfWidthAscii(s: string): string {
  return [...s]
    .map((ch) => {
      const cp = ch.codePointAt(0)!;
      return cp >= 0xff01 && cp <= 0xff5e ? String.fromCodePoint(cp - 0xfee0) : ch;
    })
    .join('');
}

function stripEdges(s: string, edge: Set<number>): string {
  const chars = [...s];
  let start = 0;
  let end = chars.length;
  const isEdge = (c: string) => edge.has(c.codePointAt(0)!) || c === ' ';
  while (start < end && isEdge(chars[start])) start++;
  while (end > start && isEdge(chars[end - 1])) end--;
  return chars.slice(start, end).join('');
}

export function normalize(input: string, language: string): string {
  let s = toHalfWidthAscii(input)
    .replace(/‘|’/g, "'")
    .replace(/“|”/g, '"');
  // JS \s also matches the ideographic space U+3000, like Dart's \s.
  s = s.replace(/\s+/g, ' ').trim();

  if (language === 'ja') {
    s = s.replace(/ /g, '');
    return stripEdges(s, JA_EDGE);
  }
  return stripEdges(s.toLowerCase(), EN_EDGE).trim();
}

export function isMatch(
  input: string,
  expected: string,
  alternatives: string[],
  language: string,
): boolean {
  const n = normalize(input, language);
  if (n.length === 0) return false;
  return [expected, ...alternatives].some((c) => normalize(c, language) === n);
}
