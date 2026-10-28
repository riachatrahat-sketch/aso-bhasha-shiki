import { AzureScores } from './evaluate';

/**
 * Azure AI Speech - Pronunciation Assessment (REST, short audio).
 * Needs an Azure Speech resource key. The free F0 tier has a monthly quota;
 * check Azure's current pricing page before relying on it.
 *
 * Audio: WAV, PCM 16-bit, 16 kHz, mono, up to about 30 seconds.
 * Docs: https://learn.microsoft.com/azure/ai-services/speech-service/how-to-pronunciation-assessment
 */
export async function assessPronunciation(params: {
  audio: Buffer;
  referenceText: string;
  /** BCP-47 locale such as en-US or ja-JP. */
  locale: string;
  key: string;
  region: string;
}): Promise<AzureScores> {
  const assessment = {
    ReferenceText: params.referenceText,
    GradingSystem: 'HundredMark',
    Granularity: 'Word',
    Dimension: 'Comprehensive',
    EnableMiscue: true,
  };
  const header = Buffer.from(JSON.stringify(assessment)).toString('base64');
  const url =
    `https://${params.region}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1` +
    `?language=${encodeURIComponent(params.locale)}&format=detailed`;

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Ocp-Apim-Subscription-Key': params.key,
      'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
      'Pronunciation-Assessment': header,
      Accept: 'application/json',
    },
    body: new Uint8Array(params.audio),
  });

  if (!res.ok) {
    throw new Error(`Azure Speech returned HTTP ${res.status}`);
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const json: any = await res.json();
  if (json.RecognitionStatus !== 'Success' || !Array.isArray(json.NBest) || json.NBest.length === 0) {
    return {
      recognized: false,
      text: '',
      pronScore: 0,
      accuracyScore: 0,
      fluencyScore: 0,
      completenessScore: 0,
    };
  }

  const best = json.NBest[0];
  // Newer API versions nest the scores under PronunciationAssessment.
  const scores = best.PronunciationAssessment ?? best;
  const num = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : 0);
  const accuracy = num(scores.AccuracyScore);

  return {
    recognized: true,
    text: String(best.Display ?? json.DisplayText ?? best.Lexical ?? ''),
    pronScore: scores.PronScore !== undefined ? num(scores.PronScore) : accuracy,
    accuracyScore: accuracy,
    fluencyScore: num(scores.FluencyScore),
    completenessScore: num(scores.CompletenessScore),
  };
}
