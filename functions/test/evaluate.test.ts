import assert from 'node:assert/strict';
import { test } from 'node:test';

import { Lesson, evaluate, expectedAnswer, taskFor } from '../src/evaluate';
import { DEFAULT_POLICY } from '../src/policy';

const item = (target: string, bn: string, sentence: string, cloze: string) => ({
  target,
  meaningBn: bn,
  meaningEn: '',
  example: sentence,
  sentence,
  cloze,
  alternatives: [] as string[],
});

const lesson: Lesson = {
  id: 'en_test_01',
  language: 'en',
  level: 'test',
  order: 1,
  title: 'Test',
  items: [
    item('tooth', 'দাঁত', 'My tooth is white.', 'My _____ is white.'),
    item('moon', 'চাঁদ', 'The moon is bright tonight.', 'The _____ is bright tonight.'),
    item('star', 'তারা', 'I see a star.', 'I see a _____.'),
  ],
  tasks: {
    speaking: [
      { kind: 'readAloud', item: 0 },
      { kind: 'translateSpeak', item: 1 },
      { kind: 'sentenceSpeak', item: 2 },
    ],
    listening: [
      { kind: 'meaning', item: 1 },
      { kind: 'sentenceBlank', item: 2 },
      { kind: 'sentenceWord', item: 0 },
    ],
    writing: [
      { kind: 'translateType', item: 2 },
      { kind: 'unscramble', item: 0 },
      { kind: 'sentenceDictation', item: 1 },
    ],
  },
};

test('old lessons without a task plan use the classic questions', () => {
  const old: Lesson = { ...lesson, tasks: undefined };
  assert.deepEqual(taskFor(old, 'speaking', 1), { kind: 'readAloud', item: 1 });
  assert.deepEqual(taskFor(old, 'listening', 0), { kind: 'meaning', item: 0 });
  assert.deepEqual(taskFor(old, 'listening', 1), { kind: 'word', item: 1 });
  assert.deepEqual(taskFor(old, 'writing', 2), { kind: 'dictation', item: 2 });
});

test('expected answers follow the task kind', () => {
  assert.equal(expectedAnswer(lesson, 'speaking', 0), 'tooth');
  assert.equal(expectedAnswer(lesson, 'speaking', 2), 'I see a star.');
  assert.equal(expectedAnswer(lesson, 'listening', 0), 'চাঁদ');
  assert.equal(expectedAnswer(lesson, 'listening', 1), 'star');
  assert.equal(expectedAnswer(lesson, 'writing', 0), 'star');
  assert.equal(expectedAnswer(lesson, 'writing', 1), 'My tooth is white.');
});

test('sentence writing ignores punctuation but not word order', () => {
  const ok = evaluate(lesson, 'writing', 2, { answer: 'the moon is bright tonight' }, DEFAULT_POLICY);
  assert.equal(ok.correct, true);
  const bad = evaluate(lesson, 'writing', 2, { answer: 'bright the moon is tonight' }, DEFAULT_POLICY);
  assert.equal(bad.correct, false);
});

test('translate typing checks the word, not the sentence', () => {
  assert.equal(evaluate(lesson, 'writing', 0, { answer: 'Star' }, DEFAULT_POLICY).correct, true);
  assert.equal(evaluate(lesson, 'writing', 0, { answer: 'I see a star.' }, DEFAULT_POLICY).correct, false);
});

test('listening checks the chosen option text', () => {
  assert.equal(evaluate(lesson, 'listening', 0, { answer: 'চাঁদ' }, DEFAULT_POLICY).correct, true);
  assert.equal(evaluate(lesson, 'listening', 2, { answer: 'tooth' }, DEFAULT_POLICY).correct, true);
  assert.equal(evaluate(lesson, 'listening', 2, { answer: 'moon' }, DEFAULT_POLICY).correct, false);
});

test('speaking a whole sentence is compared with the sentence', () => {
  const ok = evaluate(lesson, 'speaking', 2, { transcript: 'I see a star' }, DEFAULT_POLICY);
  assert.equal(ok.correct, true);
  assert.equal(ok.correctAnswer, 'I see a star.');
  const bad = evaluate(lesson, 'speaking', 2, { transcript: 'star' }, DEFAULT_POLICY);
  assert.equal(bad.correct, false);
});
