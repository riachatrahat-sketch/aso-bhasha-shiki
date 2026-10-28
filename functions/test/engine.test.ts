import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  INITIAL_QUESTION,
  QuestionMap,
  applyAttempt,
  isUnlocked,
  lessonCompleted,
  scoreTxId,
} from '../src/engine';
import { DEFAULT_POLICY, mergePolicy } from '../src/policy';

const now = new Date('2026-01-01T00:00:00Z');

test('correct answer awards +0.5 and passes the question', () => {
  const o = applyAttempt(INITIAL_QUESTION, true, DEFAULT_POLICY, now);
  assert.equal(o.delta, 0.5);
  assert.equal(o.updated.status, 'passed');
  assert.equal(o.txType, 'award');
});

test('first wrong answer costs -1, later wrong answers cost nothing (default policy)', () => {
  const first = applyAttempt(INITIAL_QUESTION, false, DEFAULT_POLICY, now);
  assert.equal(first.delta, -1);
  assert.equal(first.txType, 'penalty');
  assert.equal(first.updated.status, 'open');

  const second = applyAttempt(first.updated, false, DEFAULT_POLICY, now);
  assert.equal(second.delta, 0);
  assert.equal(second.txType, null);
  assert.equal(second.updated.wrongAttempts, 2);
});

test('wrong then correct nets -0.5 on that question', () => {
  const wrong = applyAttempt(INITIAL_QUESTION, false, DEFAULT_POLICY, now);
  const right = applyAttempt(wrong.updated, true, DEFAULT_POLICY, now);
  assert.equal(right.updated.points, -0.5);
});

test('a passed question never awards twice', () => {
  const passed = applyAttempt(INITIAL_QUESTION, true, DEFAULT_POLICY, now).updated;
  const again = applyAttempt(passed, true, DEFAULT_POLICY, now);
  assert.equal(again.alreadyPassed, true);
  assert.equal(again.delta, 0);
  assert.equal(again.txType, null);
});

test('penalty limit is configurable', () => {
  const policy = mergePolicy({ maxPenaltiesPerQuestion: 3 });
  let q = INITIAL_QUESTION;
  let total = 0;
  for (let i = 0; i < 5; i++) {
    const o = applyAttempt(q, false, policy, now);
    total += o.delta;
    q = o.updated;
  }
  assert.equal(total, -3);
});

test('transaction ids are deterministic', () => {
  assert.equal(scoreTxId('l1', 'speaking', 0, 'award', 0), 'l1_speaking_0_award');
  assert.equal(scoreTxId('l1', 'writing', 2, 'penalty', 1), 'l1_writing_2_penalty_1');
});

test('questions unlock strictly in order', () => {
  const q: QuestionMap = {};
  assert.equal(isUnlocked(q, 'listening', 0), true);
  assert.equal(isUnlocked(q, 'listening', 1), false);
  q['listening_0'] = applyAttempt(INITIAL_QUESTION, true, DEFAULT_POLICY, now).updated;
  assert.equal(isUnlocked(q, 'listening', 1), true);
  assert.equal(isUnlocked(q, 'listening', 2), false);
  assert.equal(isUnlocked(q, 'listening', 3), false);
});

test('lesson completes only when all nine questions are passed', () => {
  const q: QuestionMap = {};
  const passed = applyAttempt(INITIAL_QUESTION, true, DEFAULT_POLICY, now).updated;
  for (const a of ['speaking', 'listening', 'writing']) {
    for (let i = 0; i < 3; i++) q[`${a}_${i}`] = passed;
  }
  assert.equal(lessonCompleted(q), true);
  delete q['writing_2'];
  assert.equal(lessonCompleted(q), false);
});

test('mergePolicy ignores invalid overrides', () => {
  const p = mergePolicy({ correctPoints: 'x', wrongPenalty: -4, speakingPassSimilarity: 0.9 });
  assert.equal(p.correctPoints, 0.5);
  assert.equal(p.wrongPenalty, 1);
  assert.equal(p.speakingPassSimilarity, 0.9);
});
