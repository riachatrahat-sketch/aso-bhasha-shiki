import { Activity } from './engine';
import { isLooseMatch, isMatch, normalize } from './normalize';
import { Policy } from './policy';
import { compareSpeech } from './similarity';

export interface LessonItem {
  target: string;
  sentence?: string;
  cloze?: string | null;
  reading?: string | null;
  meaningBn: string;
  meaningEn?: string;
  example?: string;
  alternatives?: string[];
}

export interface Lesson {
  id: string;
  language: string;
  level: string;
  order: number;
  title: string;
  items: LessonItem[];
  tier?: number;
  /** Planned questions per activity, written by tools/build_lessons.py. */
  tasks?: Partial<Record<Activity, { kind: string; item: number }[]>>;
}

export interface AzureScores {
  recognized: boolean;
  text: string;
  pronScore: number;
  accuracyScore: number;
  fluencyScore: number;
  completenessScore: number;
}

export interface Evaluation {
  correct: boolean;
  correctAnswer: string;
  explanation: string;
  heard: string;
  similarity?: number;
  completeness?: number;
  accuracy?: number;
  missingWords?: string[];
  pronScore?: number;
  fluencyScore?: number;
}

export interface AnswerInput {
  answer?: string;
  transcript?: string;
}

/** The question planned for [activity] question [index]; old content falls back to classic tasks. */
export function taskFor(lesson: Lesson, activity: Activity, index: number): { kind: string; item: number } {
  const planned = lesson.tasks?.[activity]?.[index];
  if (planned) return planned;
  const kind = activity === 'speaking' ? 'readAloud' : activity === 'writing' ? 'dictation' : index % 2 === 0 ? 'meaning' : 'word';
  return { kind, item: index };
}

function sentenceOf(item: LessonItem): string {
  return item.sentence ? item.sentence : item.target;
}

/**
 * Listening rule, same as the app: kind "meaning" -> choose the Bengali meaning,
 * every other kind -> choose the target word.
 */
export function listeningCorrectAnswer(item: LessonItem, kind: string): { correct: string; type: 'meaning' | 'word' } {
  return kind === 'meaning'
    ? { correct: item.meaningBn, type: 'meaning' }
    : { correct: item.target, type: 'word' };
}

const SENTENCE_TYPING = new Set(['unscramble', 'sentenceDictation']);

function differenceHint(expected: string, typed: string, lang: string): string {
  const e = [...normalize(expected, lang)];
  const t = [...normalize(typed, lang)];
  if (t.length === 0) return 'Type what you hear.';
  let i = 0;
  while (i < e.length && i < t.length && e[i] === t[i]) i++;
  if (i >= e.length) return 'You typed extra characters at the end.';
  if (i >= t.length) return 'Your answer ends too early.';
  return `Your answer first differs at character ${i + 1}.`;
}

/** The text to say or type, or the correct option for listening. */
export function expectedAnswer(lesson: Lesson, activity: Activity, index: number): string {
  const task = taskFor(lesson, activity, index);
  const item = lesson.items[task.item];
  if (activity === 'listening') return listeningCorrectAnswer(item, task.kind).correct;
  if (activity === 'speaking') return task.kind === 'sentenceSpeak' ? sentenceOf(item) : item.target;
  return SENTENCE_TYPING.has(task.kind) ? sentenceOf(item) : item.target;
}

export function evaluate(
  lesson: Lesson,
  activity: Activity,
  index: number,
  input: AnswerInput,
  policy: Policy,
  azure?: AzureScores,
): Evaluation {
  const task = taskFor(lesson, activity, index);
  const item = lesson.items[task.item];
  const lang = lesson.language;
  const expected = expectedAnswer(lesson, activity, index);
  const alternatives = expected === item.target ? (item.alternatives ?? []) : [];

  if (activity === 'listening') {
    const { correct, type } = listeningCorrectAnswer(item, task.kind);
    const chosen = input.answer ?? '';
    return {
      correct: chosen === correct,
      correctAnswer: correct,
      explanation:
        type === 'meaning'
          ? `"${item.target}" means "${item.meaningBn}".`
          : task.kind === 'word'
            ? `The word you heard was "${item.target}" (${item.meaningBn}).`
            : `"${item.target}" (${item.meaningBn}) is the word in: ${sentenceOf(item)}`,
      heard: chosen,
    };
  }

  if (activity === 'writing') {
    const typed = input.answer ?? '';
    const ok = SENTENCE_TYPING.has(task.kind)
      ? isLooseMatch(typed, expected, lang)
      : isMatch(typed, expected, alternatives, lang);
    return {
      correct: ok,
      correctAnswer: expected,
      explanation: ok
        ? 'Well done.'
        : `The correct answer is "${expected}". ${differenceHint(expected, typed, lang)}`,
      heard: typed,
    };
  }

  // speaking
  if (azure) {
    if (!azure.recognized) {
      return {
        correct: false,
        correctAnswer: expected,
        explanation: 'We could not recognise your speech. Speak clearly and try again.',
        heard: '',
      };
    }
    const c = compareSpeech(expected, azure.text, lang, alternatives);
    const ok =
      azure.pronScore >= policy.azureMinPronScore &&
      azure.completenessScore >= policy.azureMinCompleteness;
    return {
      correct: ok,
      correctAnswer: expected,
      explanation: ok
        ? `Pronunciation score ${Math.round(azure.pronScore)}/100.`
        : `Pronunciation score ${Math.round(azure.pronScore)}/100 (needs ${policy.azureMinPronScore}). Listen to the audio and try again.`,
      heard: azure.text,
      similarity: c.similarity,
      completeness: azure.completenessScore / 100,
      accuracy: azure.accuracyScore / 100,
      missingWords: c.missing,
      pronScore: azure.pronScore,
      fluencyScore: azure.fluencyScore,
    };
  }

  const heard = input.transcript ?? '';
  if (normalize(heard, lang).length === 0) {
    return {
      correct: false,
      correctAnswer: expected,
      explanation: 'We did not hear anything. Check your microphone and try again.',
      heard,
    };
  }
  const c = compareSpeech(expected, heard, lang, alternatives);
  const ok =
    c.similarity >= policy.speakingPassSimilarity && c.completeness >= policy.speakingMinCompleteness;
  return {
    correct: ok,
    correctAnswer: expected,
    explanation: ok
      ? 'Clear speech. The recogniser understood you.'
      : c.missing.length === 0
        ? `Say it again slowly: "${expected}".`
        : `Missing or unclear: ${c.missing.join(lang === 'ja' ? '' : ', ')}. Say "${expected}" again.`,
    heard,
    similarity: c.similarity,
    completeness: c.completeness,
    accuracy: c.accuracy,
    missingWords: c.missing,
  };
}
