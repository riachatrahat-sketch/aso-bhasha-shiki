import '../../core/utils/json_helpers.dart';
import '../../data/models/lesson.dart';
import 'scoring_policy.dart';

enum QuestionStatus { open, passed }

/// What happened to one question so far.
class QuestionProgress {
  const QuestionProgress({
    required this.status,
    required this.attempts,
    required this.wrongAttempts,
    required this.penaltiesApplied,
    required this.points,
    this.completedAt,
  });

  const QuestionProgress.initial()
      : status = QuestionStatus.open,
        attempts = 0,
        wrongAttempts = 0,
        penaltiesApplied = 0,
        points = 0,
        completedAt = null;

  final QuestionStatus status;
  final int attempts;
  final int wrongAttempts;

  /// Number of penalties already charged (never exceeds the policy maximum).
  final int penaltiesApplied;

  /// Net points of this question (award minus penalties).
  final double points;
  final DateTime? completedAt;

  bool get passed => status == QuestionStatus.passed;

  factory QuestionProgress.fromMap(Map<String, dynamic> m) => QuestionProgress(
        status: m['status'] == 'passed' ? QuestionStatus.passed : QuestionStatus.open,
        attempts: asInt(m['attempts']),
        wrongAttempts: asInt(m['wrongAttempts']),
        penaltiesApplied: asInt(m['penaltiesApplied']),
        points: asDouble(m['points']),
        completedAt: parseDate(m['completedAt']),
      );

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'attempts': attempts,
        'wrongAttempts': wrongAttempts,
        'penaltiesApplied': penaltiesApplied,
        'points': points,
        'completedAt': completedAt?.toIso8601String(),
      };
}

enum ScoreTxType { award, penalty }

/// Result of applying one attempt to a question.
class ScoreOutcome {
  const ScoreOutcome({
    required this.updated,
    required this.delta,
    required this.txType,
    required this.txSeq,
    required this.alreadyPassed,
  });

  final QuestionProgress updated;

  /// Points added (positive) or removed (negative) by THIS attempt.
  final double delta;

  /// Which score transaction this attempt creates, or null when the attempt
  /// changes no points.
  final ScoreTxType? txType;

  /// Sequence number for penalty transactions (1 for the first penalty).
  final int txSeq;

  /// The question was already passed, so nothing changed.
  final bool alreadyPassed;
}

/// Deterministic id of a score transaction.
///
/// Because the id is derived from (lesson, activity, question, type, seq),
/// writing the same transaction twice hits the SAME document, which makes
/// duplicate awards impossible. Mirrored in functions/src/engine.ts.
String scoreTxId(String lessonId, Activity activity, int index, ScoreTxType type, int seq) {
  final suffix = type == ScoreTxType.award ? 'award' : 'penalty_$seq';
  return '${lessonId}_${activity.name}_${index}_$suffix';
}

class ScoringEngine {
  ScoringEngine._();

  /// Applies one attempt.
  ///
  /// - Already passed: no change, no points (blocks duplicate awards).
  /// - Correct: +correctPoints once, question becomes passed.
  /// - Wrong: -wrongPenalty, but only while penaltiesApplied is below
  ///   maxPenaltiesPerQuestion. The question stays open.
  static ScoreOutcome applyAttempt(
    QuestionProgress current,
    bool correct,
    ScoringPolicy policy,
    DateTime now,
  ) {
    if (current.passed) {
      return ScoreOutcome(
        updated: current,
        delta: 0,
        txType: null,
        txSeq: 0,
        alreadyPassed: true,
      );
    }

    final attempts = current.attempts + 1;

    if (correct) {
      return ScoreOutcome(
        updated: QuestionProgress(
          status: QuestionStatus.passed,
          attempts: attempts,
          wrongAttempts: current.wrongAttempts,
          penaltiesApplied: current.penaltiesApplied,
          points: current.points + policy.correctPoints,
          completedAt: now,
        ),
        delta: policy.correctPoints,
        txType: ScoreTxType.award,
        txSeq: 0,
        alreadyPassed: false,
      );
    }

    final chargePenalty = current.penaltiesApplied < policy.maxPenaltiesPerQuestion;
    final penalty = chargePenalty ? policy.wrongPenalty : 0.0;
    return ScoreOutcome(
      updated: QuestionProgress(
        status: QuestionStatus.open,
        attempts: attempts,
        wrongAttempts: current.wrongAttempts + 1,
        penaltiesApplied: current.penaltiesApplied + (chargePenalty ? 1 : 0),
        points: current.points - penalty,
      ),
      delta: penalty == 0 ? 0 : -penalty, // avoid -0.0
      txType: chargePenalty ? ScoreTxType.penalty : null,
      txSeq: current.penaltiesApplied + 1,
      alreadyPassed: false,
    );
  }

  /// Total shown to the user.
  static double displayTotal(double rawTotal, ScoringPolicy policy) =>
      policy.floorTotalAtZero && rawTotal < 0 ? 0 : rawTotal;
}
