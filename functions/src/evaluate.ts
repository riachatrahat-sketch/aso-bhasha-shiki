import { Activity } from './engine';
import { isMatch, normalize } from './normalize';
import { Policy } from './policy';
import { compareSpeech } from './similarity';

export interface LessonItem {
  target: string;
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

/**
 * Listening rule, same as the app: even index -> choose the Bengali meaning,
 * odd index -> choose the word that was spoken.
 */
export function listeningCorrectAnswer(item: LessonItem, index: number): { correct: string; type: 'meaning' | 'word' } {
  return index % 2 === 0
    ? { correct: item.meaningBn, type: 'meaning' }
    : { correct: item.target, type: 'word' };
}

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

export function evaluate(
  lesson: Lesson,
  activity: Activity,
  index: number,
  input: AnswerInput,
  policy: Policy,
  azure?: AzureScores,
): Evaluation {
  const item = lesson.items[index];
  const lang = lesson.language;

  if (activity === 'listening') {
    const { correct, type } = listeningCorrectAnswer(item, index);
    const chosen = input.answer ?? '';
    return {
      correct: chosen === correct,
      correctAnswer: correct,
      explanation:
        type === 'meaning'
          ? `"${item.target}" means "${item.meaningBn}".`
          : `The word you heard was "${item.target}" (${item.meaningBn}).`,
      heard: chosen,
    };
  }

  if (activity === 'writing') {
    const typed = input.answer ?? '';
    const ok = isMatch(typed, item.target, item.alternatives ?? [], lang);
    return {
      correct: ok,
      correctAnswer: item.target,
      explanation: ok
        ? 'Well done.'
        : `The correct spelling is "${item.target}". ${differenceHint(item.target, typed, lang)}`,
      heard: typed,
    };
  }

  // speaking
  if (azure) {
    if (!azure.recognized) {
      return {
        correct: false,
        correctAnswer: item.target,
        explanation: 'We could not recognise your speech. Speak clearly and try again.',
        heard: '',
      };
    }
    const c = compareSpeech(item.target, azure.text, lang, item.alternatives ?? []);
    const ok =
      azure.pronScore >= policy.azureMinPronScore &&
      azure.completenessScore >= policy.azureMinCompleteness;
    return {
      correct: ok,
      correctAnswer: item.target,
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
      correctAnswer: item.target,
      explanation: 'We did not hear anything. Check your microphone and try again.',
      heard,
    };
  }
  const c = compareSpeech(item.target, heard, lang, item.alternatives ?? []);
  const ok =
    c.similarity >= policy.speakingPassSimilarity && c.completeness >= policy.speakingMinCompleteness;
  return {
    correct: ok,
    correctAnswer: item.target,
    explanation: ok
      ? 'Clear speech. The recogniser understood you.'
      : c.missing.length === 0
        ? `Say it again slowly: "${item.target}".`
        : `Missing or unclear: ${c.missing.join(lang === 'ja' ? '' : ', ')}. Say "${item.target}" again.`,
    heard,
    similarity: c.similarity,
    completeness: c.completeness,
    accuracy: c.accuracy,
    missingWords: c.missing,
  };
}
