import { normalize } from './normalize';

/** Mirror of lib/core/utils/text_similarity.dart. */
export interface SpeechComparison {
  similarity: number;
  completeness: number;
  accuracy: number;
  missing: string[];
  heard: string;
}

export function levenshtein(a: number[], b: number[]): number {
  if (a.length === 0) return b.length;
  if (b.length === 0) return a.length;
  let prev = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const cur = new Array<number>(b.length + 1).fill(0);
    cur[0] = i;
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      cur[j] = Math.min(cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost);
    }
    prev = cur;
  }
  return prev[b.length];
}

export function ratio(a: string, b: string): number {
  const ra = [...a].map((c) => c.codePointAt(0)!);
  const rb = [...b].map((c) => c.codePointAt(0)!);
  const longest = Math.max(ra.length, rb.length);
  if (longest === 0) return 1;
  return 1 - levenshtein(ra, rb) / longest;
}

function lcsLength(a: string[], b: string[]): number {
  if (a.length === 0 || b.length === 0) return 0;
  let prev = new Array<number>(b.length + 1).fill(0);
  for (let i = 1; i <= a.length; i++) {
    const cur = new Array<number>(b.length + 1).fill(0);
    for (let j = 1; j <= b.length; j++) {
      cur[j] = a[i - 1] === b[j - 1] ? prev[j - 1] + 1 : Math.max(prev[j], cur[j - 1]);
    }
    prev = cur;
  }
  return prev[b.length];
}

function compareOne(expected: string, heard: string, language: string): SpeechComparison {
  const units = (s: string) =>
    language === 'ja' ? [...s] : s.split(' ').filter((w) => w.length > 0);
  const e = units(expected);
  const h = units(heard);
  const lcs = lcsLength(e, h);

  const remaining = [...h];
  const missing: string[] = [];
  for (const unit of e) {
    const i = remaining.indexOf(unit);
    if (i >= 0) remaining.splice(i, 1);
    else missing.push(unit);
  }

  return {
    similarity: heard.length === 0 ? 0 : ratio(expected, heard),
    completeness: e.length === 0 ? 0 : lcs / e.length,
    accuracy: h.length === 0 ? 0 : lcs / h.length,
    missing,
    heard,
  };
}

/** Best comparison over the target and its alternative spellings. */
export function compareSpeech(
  expected: string,
  heard: string,
  language: string,
  alternatives: string[] = [],
): SpeechComparison {
  const heardN = normalize(heard, language);
  let best: SpeechComparison | undefined;
  for (const candidate of [expected, ...alternatives]) {
    const c = compareOne(normalize(candidate, language), heardN, language);
    if (!best || c.similarity > best.similarity) best = c;
  }
  return best!;
}
