import 'package:flutter_test/flutter_test.dart';
import 'package:lingobridge_ai/data/models/lesson.dart';
import 'package:lingobridge_ai/domain/scoring/scoring_engine.dart';
import 'package:lingobridge_ai/domain/scoring/scoring_policy.dart';

void main() {
  const policy = ScoringPolicy.defaults;
  final now = DateTime(2026, 1, 1);
  const fresh = QuestionProgress.initial();

  group('score calculation', () {
    test('a correct answer awards +0.5 and passes the question', () {
      final o = ScoringEngine.applyAttempt(fresh, true, policy, now);
      expect(o.delta, 0.5);
      expect(o.updated.passed, isTrue);
      expect(o.txType, ScoreTxType.award);
      expect(o.updated.completedAt, now);
    });

    test('the first wrong answer costs -1 and keeps the question open', () {
      final o = ScoringEngine.applyAttempt(fresh, false, policy, now);
      expect(o.delta, -1);
      expect(o.txType, ScoreTxType.penalty);
      expect(o.txSeq, 1);
      expect(o.updated.passed, isFalse);
      expect(o.updated.wrongAttempts, 1);
    });

    test('later wrong answers on the same question cost nothing (default policy)', () {
      final first = ScoringEngine.applyAttempt(fresh, false, policy, now);
      final second = ScoringEngine.applyAttempt(first.updated, false, policy, now);
      expect(second.delta, 0);
      expect(second.txType, isNull);
      expect(second.updated.wrongAttempts, 2);
      expect(second.updated.attempts, 2);
      expect(second.updated.points, -1);
    });

    test('wrong then correct nets -0.5 for the question', () {
      final wrong = ScoringEngine.applyAttempt(fresh, false, policy, now);
      final right = ScoringEngine.applyAttempt(wrong.updated, true, policy, now);
      expect(right.updated.points, -0.5);
      expect(right.updated.passed, isTrue);
    });

    test('the penalty limit is configurable', () {
      const strict = ScoringPolicy(maxPenaltiesPerQuestion: 3);
      var q = fresh;
      var total = 0.0;
      for (var i = 0; i < 5; i++) {
        final o = ScoringEngine.applyAttempt(q, false, strict, now);
        total += o.delta;
        q = o.updated;
      }
      expect(total, -3);
    });

    test('the displayed total never goes below zero when floored', () {
      expect(ScoringEngine.displayTotal(-2.5, policy), 0);
      expect(ScoringEngine.displayTotal(3, policy), 3);
      expect(
        ScoringEngine.displayTotal(-2.5, const ScoringPolicy(floorTotalAtZero: false)),
        -2.5,
      );
    });
  });

  group('duplicate score prevention', () {
    test('a passed question never awards points again', () {
      final passed = ScoringEngine.applyAttempt(fresh, true, policy, now).updated;
      final again = ScoringEngine.applyAttempt(passed, true, policy, now);
      expect(again.alreadyPassed, isTrue);
      expect(again.delta, 0);
      expect(again.txType, isNull);
      expect(again.updated.points, 0.5);
    });

    test('a wrong attempt after passing changes nothing', () {
      final passed = ScoringEngine.applyAttempt(fresh, true, policy, now).updated;
      final again = ScoringEngine.applyAttempt(passed, false, policy, now);
      expect(again.alreadyPassed, isTrue);
      expect(again.delta, 0);
    });

    test('transaction ids are deterministic', () {
      expect(
        scoreTxId('l1', Activity.speaking, 0, ScoreTxType.award, 0),
        'l1_speaking_0_award',
      );
      expect(
        scoreTxId('l1', Activity.writing, 2, ScoreTxType.penalty, 1),
        'l1_writing_2_penalty_1',
      );
      // Same inputs, same id: writing it twice hits the same document.
      expect(
        scoreTxId('l1', Activity.writing, 2, ScoreTxType.penalty, 1),
        scoreTxId('l1', Activity.writing, 2, ScoreTxType.penalty, 1),
      );
    });
  });
}
