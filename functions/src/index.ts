import { initializeApp } from 'firebase-admin/app';
import { FieldValue, Firestore, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { defineSecret, defineString } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { assessPronunciation } from './azure';
import {
  ACTIVITIES,
  Activity,
  INITIAL_QUESTION,
  QUESTIONS_PER_ACTIVITY,
  QuestionMap,
  QuestionProgress,
  applyAttempt,
  isUnlocked,
  lessonCompleted,
  questionKey,
  scoreTxId,
} from './engine';
import { AzureScores, Lesson, evaluate } from './evaluate';
import { Policy, mergePolicy } from './policy';

initializeApp();

// Azure is optional. Without the secret, speaking uses the transcript path.
const azureKey = defineSecret('AZURE_SPEECH_KEY');
const azureRegion = defineString('AZURE_SPEECH_REGION', { default: 'eastus' });

const TTS_LOCALE: Record<string, string> = { en: 'en-US', ja: 'ja-JP' };

// ---- Policy (cached for one minute) ----------------------------------------

let cachedPolicy: { value: Policy; at: number } | undefined;

async function loadPolicy(db: Firestore): Promise<Policy> {
  if (cachedPolicy && Date.now() - cachedPolicy.at < 60_000) return cachedPolicy.value;
  const snap = await db.doc('config/scoring').get();
  const value = mergePolicy(snap.exists ? (snap.data() as Record<string, unknown>) : undefined);
  cachedPolicy = { value, at: Date.now() };
  return value;
}

// ---- Request validation ----------------------------------------------------

interface ParsedRequest {
  lessonId: string;
  activity: Activity;
  index: number;
  answer?: string;
  transcript?: string;
  audioBase64?: string;
  dayKey: string;
}

const MAX_TEXT = 500;
const MAX_AUDIO_BASE64 = 2_000_000; // about 1.5 MB of audio, plenty for 30 s at 16 kHz mono

function parseRequest(data: unknown): ParsedRequest {
  const d = (data ?? {}) as Record<string, unknown>;
  const lessonId = typeof d.lessonId === 'string' ? d.lessonId : '';
  const activity = d.activity as Activity;
  const index = d.index;

  if (!/^[A-Za-z0-9_]{1,64}$/.test(lessonId)) throw new HttpsError('invalid-argument', 'Invalid lesson.');
  if (!ACTIVITIES.includes(activity)) throw new HttpsError('invalid-argument', 'Invalid activity.');
  if (typeof index !== 'number' || !Number.isInteger(index) || index < 0 || index >= QUESTIONS_PER_ACTIVITY) {
    throw new HttpsError('invalid-argument', 'Invalid question.');
  }

  const text = (v: unknown): string | undefined => {
    if (v === undefined || v === null) return undefined;
    if (typeof v !== 'string' || v.length > MAX_TEXT) throw new HttpsError('invalid-argument', 'Invalid answer.');
    return v;
  };
  const audio = d.audioBase64;
  if (audio !== undefined && (typeof audio !== 'string' || audio.length > MAX_AUDIO_BASE64)) {
    throw new HttpsError('invalid-argument', 'Invalid audio.');
  }

  return {
    lessonId,
    activity,
    index,
    answer: text(d.answer),
    transcript: text(d.transcript),
    audioBase64: audio as string | undefined,
    dayKey: typeof d.dayKey === 'string' ? d.dayKey : '',
  };
}

/**
 * The app sends the learner's local date. Accept it only when it is within a
 * day of the server's UTC date (covers every time zone), else use the server date.
 */
function resolveDayKey(candidate: string, now: Date): string {
  const serverDay = now.toISOString().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(candidate)) return serverDay;
  const diffDays = Math.abs(Date.parse(`${candidate}T00:00:00Z`) - Date.parse(`${serverDay}T00:00:00Z`)) / 86_400_000;
  return diffDays <= 1 ? candidate : serverDay;
}

// ---- Firestore <-> engine mapping ------------------------------------------

function readQuestions(data: FirebaseFirestore.DocumentData | undefined): QuestionMap {
  const raw = (data?.questions ?? {}) as Record<string, Record<string, unknown>>;
  const result: QuestionMap = {};
  for (const [k, v] of Object.entries(raw)) {
    result[k] = {
      status: v.status === 'passed' ? 'passed' : 'open',
      attempts: Number(v.attempts ?? 0),
      wrongAttempts: Number(v.wrongAttempts ?? 0),
      penaltiesApplied: Number(v.penaltiesApplied ?? 0),
      points: Number(v.points ?? 0),
      completedAt: v.completedAt instanceof Timestamp ? v.completedAt.toDate() : null,
    };
  }
  return result;
}

function writeQuestion(q: QuestionProgress) {
  return {
    status: q.status,
    attempts: q.attempts,
    wrongAttempts: q.wrongAttempts,
    penaltiesApplied: q.penaltiesApplied,
    points: q.points,
    completedAt: q.completedAt ? Timestamp.fromDate(q.completedAt) : null,
  };
}

// ---- submitAttempt ---------------------------------------------------------

/**
 * The ONLY place where answers are judged and scores are written.
 * Firestore rules deny client writes to progress, stats, transactions,
 * mistakes and streaks, so the app cannot award itself points.
 */
export const submitAttempt = onCall(
  { secrets: [azureKey], timeoutSeconds: 60, memory: '256MiB', maxInstances: 10 },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Please sign in.');
    if (request.auth?.token.email_verified !== true) {
      throw new HttpsError('failed-precondition', 'Please verify your email address first.');
    }

    const req = parseRequest(request.data);
    const db = getFirestore();
    const now = new Date();
    const day = resolveDayKey(req.dayKey, now);

    const lessonSnap = await db.doc(`lessons/${req.lessonId}`).get();
    if (!lessonSnap.exists) throw new HttpsError('not-found', 'This lesson does not exist.');
    const lesson = lessonSnap.data() as Lesson;
    if (!Array.isArray(lesson.items) || !lesson.items[req.index]) {
      throw new HttpsError('not-found', 'This question does not exist.');
    }

    const policy = await loadPolicy(db);
    const progressRef = db.doc(`users/${uid}/lessonProgress/${lesson.id}`);
    const key = questionKey(req.activity, req.index);

    // Cheap pre-check, before spending an Azure call on a blocked question.
    const pre = readQuestions((await progressRef.get()).data());
    if (!isUnlocked(pre, req.activity, req.index)) {
      throw new HttpsError('failed-precondition', 'Finish the previous question first.');
    }

    // Optional pronunciation scoring.
    let azure: AzureScores | undefined;
    if (req.activity === 'speaking' && req.audioBase64 && pre[key]?.status !== 'passed') {
      const secret = azureKey.value();
      // "unset" is the placeholder value recommended in the README so the
      // function can be deployed without an Azure account.
      if (!secret || secret === 'unset') {
        throw new HttpsError(
          'failed-precondition',
          'Pronunciation scoring is not configured. Use speech-to-text mode or add the Azure key.',
        );
      }
      try {
        azure = await assessPronunciation({
          audio: Buffer.from(req.audioBase64, 'base64'),
          referenceText: lesson.items[req.index].target,
          locale: TTS_LOCALE[lesson.language] ?? 'en-US',
          key: secret,
          region: azureRegion.value(),
        });
      } catch {
        throw new HttpsError('unavailable', 'The pronunciation service is unavailable. Please try again.');
      }
    }

    const ev = evaluate(lesson, req.activity, req.index, { answer: req.answer, transcript: req.transcript }, policy, azure);

    return db.runTransaction(async (t) => {
      const statsRef = db.doc(`users/${uid}/stats/summary`);
      const dailyRef = db.doc(`users/${uid}/dailyStreaks/${day}`);

      // Firestore transactions: all reads first, then all writes.
      const progressSnap = await t.get(progressRef);
      const questions = readQuestions(progressSnap.data());

      // Re-check inside the transaction (two quick requests could race).
      if (!isUnlocked(questions, req.activity, req.index)) {
        throw new HttpsError('failed-precondition', 'Finish the previous question first.');
      }

      const current = questions[key] ?? INITIAL_QUESTION;
      const outcome = applyAttempt(current, ev.correct, policy, now);
      const wasCompleted = progressSnap.data()?.completed === true;

      const base = {
        correct: ev.correct,
        passed: outcome.updated.status === 'passed',
        alreadyPassed: outcome.alreadyPassed,
        questionPoints: outcome.updated.points,
        correctAnswer: ev.correctAnswer,
        explanation: ev.explanation,
        heard: ev.heard,
        similarity: ev.similarity ?? null,
        completeness: ev.completeness ?? null,
        accuracy: ev.accuracy ?? null,
        pronScore: ev.pronScore ?? null,
        fluencyScore: ev.fluencyScore ?? null,
        missingWords: ev.missingWords ?? [],
      };

      // Nothing to write: already passed earlier (no duplicate award).
      if (outcome.alreadyPassed) {
        return { ...base, delta: 0, lessonCompleted: wasCompleted };
      }

      // Duplicate-transaction guard. The transaction id is deterministic.
      let txRef: FirebaseFirestore.DocumentReference | undefined;
      let delta = outcome.delta;
      if (outcome.txType) {
        const txId = scoreTxId(lesson.id, req.activity, req.index, outcome.txType, outcome.txSeq);
        txRef = db.doc(`users/${uid}/scoreTransactions/${txId}`);
        const txSnap = await t.get(txRef);
        if (txSnap.exists) {
          // Already applied once; apply nothing again.
          return { ...base, delta: 0, lessonCompleted: wasCompleted };
        }
      }

      const nextQuestions: QuestionMap = { ...questions, [key]: outcome.updated };
      const done = lessonCompleted(nextQuestions);

      t.set(progressRef, {
        lessonId: lesson.id,
        language: lesson.language,
        level: lesson.level,
        questions: Object.fromEntries(Object.entries(nextQuestions).map(([k, v]) => [k, writeQuestion(v)])),
        completed: done,
        completedAt: done ? (wasCompleted ? progressSnap.data()?.completedAt ?? Timestamp.fromDate(now) : Timestamp.fromDate(now)) : null,
        updatedAt: FieldValue.serverTimestamp(),
      });

      if (txRef && outcome.txType) {
        t.create(txRef, {
          lessonId: lesson.id,
          activity: req.activity,
          questionIndex: req.index,
          type: outcome.txType,
          delta,
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      if (delta !== 0) {
        t.set(statsRef, { totalPoints: FieldValue.increment(delta), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      }

      if (delta !== 0 || outcome.updated.status === 'passed') {
        t.set(
          dailyRef,
          {
            date: day,
            passed: FieldValue.increment(outcome.updated.status === 'passed' ? 1 : 0),
            points: FieldValue.increment(delta),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      if (!ev.correct) {
        t.create(db.collection(`users/${uid}/mistakes`).doc(), {
          lessonId: lesson.id,
          activity: req.activity,
          index: req.index,
          prompt: lesson.items[req.index].target,
          expected: ev.correctAnswer,
          given: ev.heard.slice(0, 200),
          at: FieldValue.serverTimestamp(),
        });
      }

      return { ...base, delta, lessonCompleted: done };
    });
  },
);

// ---- deleteAccountData -----------------------------------------------------

/**
 * Deletes all Firestore data of the caller (profile and every sub-collection).
 * The app then deletes the Firebase Auth user itself.
 */
export const deleteAccountData = onCall({ maxInstances: 5 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Please sign in.');
  const db = getFirestore();
  await db.recursiveDelete(db.doc(`users/${uid}`));
  return { ok: true };
});
