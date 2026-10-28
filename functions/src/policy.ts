/** Scoring policy. Defaults can be overridden by the Firestore document config/scoring. */
export interface Policy {
  /** Points for passing a question (once per question). */
  correctPoints: number;
  /** Points removed for a wrong attempt. */
  wrongPenalty: number;
  /**
   * How many wrong attempts on ONE question may cost points.
   * 1 means only the first wrong attempt is penalised, so retries cannot
   * push the score down without limit. Use a large number to penalise every
   * wrong attempt.
   */
  maxPenaltiesPerQuestion: number;
  /** Minimum text similarity (0..1) for a spoken answer in transcript mode. */
  speakingPassSimilarity: number;
  /**
   * Transcript mode: minimum completeness (0..1), i.e. the share of target
   * words (English) or characters (Japanese) that were heard. Stops "tank you"
   * from passing as "thank you" on character similarity alone.
   */
  speakingMinCompleteness: number;
  /** Azure mode: minimum overall pronunciation score (0..100). */
  azureMinPronScore: number;
  /** Azure mode: minimum completeness (0..100). */
  azureMinCompleteness: number;
}

export const DEFAULT_POLICY: Policy = {
  correctPoints: 0.5,
  wrongPenalty: 1,
  maxPenaltiesPerQuestion: 1,
  speakingPassSimilarity: 0.8,
  speakingMinCompleteness: 0.8,
  azureMinPronScore: 60,
  azureMinCompleteness: 70,
};

/** Merges numeric overrides from Firestore into the defaults, ignoring junk values. */
export function mergePolicy(overrides: Record<string, unknown> | undefined): Policy {
  const result: Policy = { ...DEFAULT_POLICY };
  if (!overrides) return result;
  for (const key of Object.keys(DEFAULT_POLICY) as (keyof Policy)[]) {
    const v = overrides[key];
    if (typeof v === 'number' && Number.isFinite(v) && v >= 0) result[key] = v;
  }
  return result;
}
