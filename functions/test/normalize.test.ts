import assert from 'node:assert/strict';
import { test } from 'node:test';

import { DEFAULT_POLICY } from '../src/policy';
import { Lesson, evaluate } from '../src/evaluate';
import { isMatch, normalize } from '../src/normalize';
import { compareSpeech } from '../src/similarity';

// These cases are identical to test/answer_normalizer_test.dart in the app.
test('English: case, spaces and edge punctuation are ignored', () => {
  assert.equal(normalize('  Hello  ', 'en'), 'hello');
  assert.equal(normalize('How are you?', 'en'), 'how are you');
  assert.equal(normalize('Good   morning.', 'en'), 'good morning');
  assert.equal(normalize('ＨＥＬＬＯ！', 'en'), 'hello');
  assert.equal(normalize('It’s', 'en'), "it's");
});

test('English: wrong spelling is NOT accepted', () => {
  assert.equal(isMatch('Helo', 'Hello', [], 'en'), false);
  assert.equal(isMatch('Good mornin', 'Good morning', [], 'en'), false);
  assert.equal(isMatch('', 'Hello', [], 'en'), false);
});

test('Japanese: spaces and trailing punctuation ignored', () => {
  assert.equal(normalize('おはよう ございます。', 'ja'), 'おはようございます');
  assert.equal(normalize('　すみません！', 'ja'), 'すみません');
});

test('Japanese: hiragana vs katakana is NOT accepted', () => {
  assert.equal(isMatch('スシ', 'すし', [], 'ja'), false);
  assert.equal(isMatch('すし', 'すし', [], 'ja'), true);
});

test('Japanese: kanji accepted only through listed alternatives', () => {
  assert.equal(isMatch('寿司', 'すし', [], 'ja'), false);
  assert.equal(isMatch('寿司', 'すし', ['寿司'], 'ja'), true);
});

const lesson: Lesson = {
  id: 'en_test',
  language: 'en',
  level: 'beginner',
  order: 1,
  title: 'Test',
  items: [
    { target: 'Hello', meaningBn: 'হ্যালো', alternatives: [] },
    { target: 'Good morning', meaningBn: 'শুভ সকাল', alternatives: [] },
    { target: 'Thank you', meaningBn: 'ধন্যবাদ', alternatives: [] },
  ],
};

test('writing evaluation', () => {
  assert.equal(evaluate(lesson, 'writing', 1, { answer: 'good morning' }, DEFAULT_POLICY).correct, true);
  const bad = evaluate(lesson, 'writing', 1, { answer: 'good mornig' }, DEFAULT_POLICY);
  assert.equal(bad.correct, false);
  assert.match(bad.explanation, /Good morning/);
});

test('listening: even index = meaning, odd index = word', () => {
  assert.equal(evaluate(lesson, 'listening', 0, { answer: 'হ্যালো' }, DEFAULT_POLICY).correct, true);
  assert.equal(evaluate(lesson, 'listening', 0, { answer: 'Hello' }, DEFAULT_POLICY).correct, false);
  assert.equal(evaluate(lesson, 'listening', 1, { answer: 'Good morning' }, DEFAULT_POLICY).correct, true);
});

test('speaking via transcript uses the similarity threshold', () => {
  assert.equal(evaluate(lesson, 'speaking', 2, { transcript: 'thank you' }, DEFAULT_POLICY).correct, true);
  assert.equal(evaluate(lesson, 'speaking', 2, { transcript: 'tank you' }, DEFAULT_POLICY).correct, false);
  assert.equal(evaluate(lesson, 'speaking', 2, { transcript: '' }, DEFAULT_POLICY).correct, false);
});

test('speaking via Azure scores', () => {
  const good = evaluate(lesson, 'speaking', 0, {}, DEFAULT_POLICY, {
    recognized: true, text: 'Hello.', pronScore: 82, accuracyScore: 85, fluencyScore: 80, completenessScore: 100,
  });
  assert.equal(good.correct, true);
  const poor = evaluate(lesson, 'speaking', 0, {}, DEFAULT_POLICY, {
    recognized: true, text: 'Hallo', pronScore: 41, accuracyScore: 40, fluencyScore: 50, completenessScore: 100,
  });
  assert.equal(poor.correct, false);
});

test('compareSpeech reports missing words', () => {
  const c = compareSpeech('Where is the bus stop?', 'where is bus stop', 'en');
  assert.deepEqual(c.missing, ['the']);
  assert.ok(c.completeness < 1);
});
