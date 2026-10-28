/// Scoring rules. Everything is configurable here (and on the server in
/// functions/src/policy.ts, optionally overridden by the Firestore document
/// config/scoring).
class ScoringPolicy {
  const ScoringPolicy({
    this.correctPoints = 0.5,
    this.wrongPenalty = 1.0,
    this.maxPenaltiesPerQuestion = 1,
    this.floorTotalAtZero = true,
    this.speakingPassSimilarity = 0.8,
    this.speakingMinCompleteness = 0.8,
  });

  /// Points for passing a question (once per question).
  final double correctPoints;

  /// Points removed for a wrong attempt.
  final double wrongPenalty;

  /// How many wrong attempts on ONE question may cost points.
  ///
  /// 1 (default): only the first wrong attempt is penalised, so retrying a
  /// hard question cannot drive the score down without limit.
  /// Use a large number (e.g. 999) for "every wrong attempt costs a point".
  final int maxPenaltiesPerQuestion;

  /// When true, the total shown to the user never goes below zero.
  final bool floorTotalAtZero;

  /// Minimum similarity (0..1) for a spoken answer to pass in STT mode.
  final double speakingPassSimilarity;

  /// Minimum share (0..1) of target words (English) or characters (Japanese)
  /// that must be heard. Stops "tank you" passing as "thank you" on
  /// character similarity alone.
  final double speakingMinCompleteness;

  static const defaults = ScoringPolicy();
}
