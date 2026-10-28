import { Policy } from './policy';

/**
 * Scoring engine. Mirror of lib/domain/scoring/scoring_engine.dart and
 * progression.dart. This server copy is the one that counts.
 */
export type Activity = 'speaking' | 'listening' | 'writing';
export const ACTIVITIES: Activity[] = ['speaking', 'listening', 'writing'];
export const QUESTIONS_PER_ACTIVITY = 3;

export interface QuestionProgress {
  status: 'open' | 'passed';
  attempts: number;
  wrongAttempts: number;
  penaltiesApplied: number;
  points: number;
  completedAt?: Date | null;
}

export const INITIAL_QUESTION: QuestionProgress = {
  status: 'open',
  attempts: 0,
  wrongAttempts: 0,
  penaltiesApplied: 0,
  points: 0,
  completedAt: null,
};

export type TxType = 'award' | 'penalty';

export interface Outcome {
  updated: QuestionProgress;
  delta: number;
  txType: TxType | null;
  txSeq: number;
  alreadyPassed: boolean;
}

/** Deterministic id: writing the same transaction twice hits the same document. */
export function scoreTxId(
  lessonId: string,
  activity: Activity,
  index: number,
  type: TxType,
  seq: number,
): string {
  const suffix = type === 'award' ? 'award' : `penalty_${seq}`;
  return `${lessonId}_${activity}_${index}_${suffix}`;
}

export function applyAttempt(
  current: QuestionProgress,
  correct: boolean,
  policy: Policy,
  now: Date,
): Outcome {
  // Already passed: nothing changes, no duplicate award.
  if (current.status === 'passed') {
    return { updated: current, delta: 0, txType: null, txSeq: 0, alreadyPassed: true };
  }

  const attempts = current.attempts + 1;

  if (correct) {
    return {
      updated: {
        status: 'passed',
        attempts,
        wrongAttempts: current.wrongAttempts,
        penaltiesApplied: current.penaltiesApplied,
        points: current.points + policy.correctPoints,
        completedAt: now,
      },
      delta: policy.correctPoints,
      txType: 'award',
      txSeq: 0,
      alreadyPassed: false,
    };
  }

  const chargePenalty = current.penaltiesApplied < policy.maxPenaltiesPerQuestion;
  const penalty = chargePenalty ? policy.wrongPenalty : 0;
  return {
    updated: {
      status: 'open',
      attempts,
      wrongAttempts: current.wrongAttempts + 1,
      penaltiesApplied: current.penaltiesApplied + (chargePenalty ? 1 : 0),
      points: current.points - penalty,
      completedAt: null,
    },
    delta: penalty === 0 ? 0 : -penalty, // avoid -0
    txType: chargePenalty ? 'penalty' : null,
    txSeq: current.penaltiesApplied + 1,
    alreadyPassed: false,
  };
}

// ---- Progression -----------------------------------------------------------

export type QuestionMap = Record<string, QuestionProgress>;

export const questionKey = (a: Activity, i: number) => `${a}_${i}`;

export function isPassed(q: QuestionMap, a: Activity, i: number): boolean {
  return q[questionKey(a, i)]?.status === 'passed';
}

/** Question i is attempt-able only when all earlier questions are passed. */
export function isUnlocked(q: QuestionMap, a: Activity, index: number): boolean {
  if (index < 0 || index >= QUESTIONS_PER_ACTIVITY) return false;
  for (let i = 0; i < index; i++) if (!isPassed(q, a, i)) return false;
  return true;
}

export function lessonCompleted(q: QuestionMap): boolean {
  return ACTIVITIES.every((a) =>
    Array.from({ length: QUESTIONS_PER_ACTIVITY }, (_, i) => isPassed(q, a, i)).every(Boolean),
  );
}
