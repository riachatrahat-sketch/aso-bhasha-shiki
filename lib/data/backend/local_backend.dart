import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/json_helpers.dart';
import '../../domain/attempt_evaluator.dart';
import '../../domain/scoring/progression.dart';
import '../../domain/scoring/scoring_engine.dart';
import '../../domain/scoring/scoring_policy.dart';
import '../catalog/lesson_catalog.dart';
import '../models/attempt.dart';
import '../models/lesson_progress.dart';
import '../models/user_data.dart';
import 'learning_backend.dart';

/// Runs scoring on the device and keeps progress in SharedPreferences.
///
/// It uses exactly the same ScoringEngine, Progression and AttemptEvaluator as
/// the tests, so behaviour matches the server. It is NOT tamper-proof (the
/// user can edit local storage). Use it for demos; use FirebaseBackend for
/// real accounts.
class LocalBackend implements LearningBackend {
  LocalBackend({
    required this.prefs,
    required this.catalog,
    this.policy = ScoringPolicy.defaults,
    DateTime Function()? clock,
  })  : evaluator = AttemptEvaluator(catalog, policy: policy),
        _clock = clock ?? DateTime.now;

  final SharedPreferences prefs;
  final LessonCatalog catalog;
  final ScoringPolicy policy;
  final AttemptEvaluator evaluator;
  final DateTime Function() _clock;

  final _changes = StreamController<void>.broadcast();

  String _key(String uid) => 'local_progress_$uid';

  _State _load(String uid) {
    final raw = prefs.getString(_key(uid));
    if (raw == null) return _State();
    try {
      return _State.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return _State();
    }
  }

  Future<void> _save(String uid, _State s) async {
    await prefs.setString(_key(uid), jsonEncode(s.toJson()));
    _changes.add(null);
  }

  Stream<T> _watch<T>(String uid, T Function(_State) read) async* {
    yield read(_load(uid));
    await for (final _ in _changes.stream) {
      yield read(_load(uid));
    }
  }

  @override
  Stream<Map<String, LessonProgress>> watchProgress(String uid) =>
      _watch(uid, (s) => s.lessons);

  @override
  Stream<UserStats> watchStats(String uid) =>
      _watch(uid, (s) => UserStats(totalPoints: s.totalPoints));

  @override
  Stream<List<DailyActivity>> watchDaily(String uid) => _watch(
        uid,
        (s) => [
          for (final e in s.daily.entries)
            DailyActivity(date: e.key, passed: e.value.passed, points: e.value.points),
        ],
      );

  @override
  Stream<List<Mistake>> watchMistakes(String uid) =>
      _watch(uid, (s) => (s.mistakes.reversed.take(30)).toList());

  @override
  Future<AttemptResult> submit(String uid, AttemptRequest req) async {
    final lesson = catalog.lessonById(req.lessonId);
    if (lesson == null) throw AppException('This lesson no longer exists.');
    if (req.index < 0 || req.index >= Progression.questionsPerActivity) {
      throw AppException('Invalid question.');
    }

    final state = _load(uid);
    final lp = state.lessons[lesson.id] ?? LessonProgress.empty(lesson.id);

    // Unlock rule: a question can only be attempted after the previous ones passed.
    if (!Progression.isUnlocked(lp, req.activity, req.index)) {
      throw AppException('Finish the previous question first.');
    }

    final current = Progression.questionOf(lp, req.activity, req.index);
    final eval = evaluator.evaluate(lesson, req);
    final outcome = ScoringEngine.applyAttempt(current, eval.correct, policy, _clock());

    // Already passed: nothing may change (no duplicate award).
    if (outcome.alreadyPassed) {
      return _result(eval, outcome, lessonCompleted: Progression.lessonCompleted(lp));
    }

    // Duplicate-transaction guard. The id is deterministic, so a transaction
    // that was already applied can never be applied twice.
    var delta = outcome.delta;
    if (outcome.txType != null) {
      final txId = scoreTxId(lesson.id, req.activity, req.index, outcome.txType!, outcome.txSeq);
      if (!state.txIds.add(txId)) {
        delta = 0;
      }
    }

    final questions = Map<String, QuestionProgress>.from(lp.questions)
      ..[Progression.key(req.activity, req.index)] = outcome.updated;
    var updated = lp.copyWith(questions: questions);
    final done = Progression.lessonCompleted(updated);
    if (done && !lp.completed) {
      updated = updated.copyWith(completed: true, completedAt: _clock());
    }
    state.lessons[lesson.id] = updated;
    state.totalPoints += delta;

    final day = dayKey(_clock());
    final daily = state.daily[day] ?? _Day(0, 0);
    state.daily[day] = _Day(
      daily.passed + (outcome.updated.passed ? 1 : 0),
      daily.points + delta,
    );

    if (!eval.correct) {
      final item = lesson.items[req.index];
      state.mistakes.add(Mistake(
        id: '${_clock().microsecondsSinceEpoch}',
        lessonId: lesson.id,
        activity: req.activity,
        index: req.index,
        prompt: item.target,
        expected: eval.correctAnswer,
        given: eval.heard ?? '',
        at: _clock(),
      ));
      if (state.mistakes.length > 50) state.mistakes.removeAt(0);
    }

    await _save(uid, state);
    return _result(eval, outcome, delta: delta, lessonCompleted: done);
  }

  AttemptResult _result(
    Evaluation eval,
    ScoreOutcome outcome, {
    double? delta,
    required bool lessonCompleted,
  }) {
    final c = eval.comparison;
    return AttemptResult(
      correct: eval.correct,
      passed: outcome.updated.passed,
      alreadyPassed: outcome.alreadyPassed,
      delta: delta ?? outcome.delta,
      questionPoints: outcome.updated.points,
      correctAnswer: eval.correctAnswer,
      explanation: eval.explanation,
      lessonCompleted: lessonCompleted,
      heard: eval.heard,
      similarity: c?.similarity,
      completeness: c?.completeness,
      accuracy: c?.accuracy,
      missingWords: c?.missing ?? const [],
    );
  }

  @override
  Future<void> deleteAllData(String uid) async {
    await prefs.remove(_key(uid));
    _changes.add(null);
  }
}

class _Day {
  _Day(this.passed, this.points);
  final int passed;
  final double points;
}

class _State {
  _State();

  final Map<String, LessonProgress> lessons = {};
  final Set<String> txIds = {};
  double totalPoints = 0;
  final Map<String, _Day> daily = {};
  final List<Mistake> mistakes = [];

  factory _State.fromJson(Map<String, dynamic> j) {
    final s = _State();
    final lessons = (j['lessons'] as Map?) ?? const {};
    for (final e in lessons.entries) {
      s.lessons[e.key as String] =
          LessonProgress.fromMap(e.key as String, Map<String, dynamic>.from(e.value as Map));
    }
    s.txIds.addAll(((j['txIds'] as List?) ?? const []).cast<String>());
    s.totalPoints = asDouble(j['totalPoints']);
    final daily = (j['daily'] as Map?) ?? const {};
    for (final e in daily.entries) {
      final m = Map<String, dynamic>.from(e.value as Map);
      s.daily[e.key as String] = _Day(asInt(m['passed']), asDouble(m['points']));
    }
    for (final m in ((j['mistakes'] as List?) ?? const [])) {
      final map = Map<String, dynamic>.from(m as Map);
      s.mistakes.add(Mistake.fromMap(map['id'] as String? ?? '', map));
    }
    return s;
  }

  Map<String, dynamic> toJson() => {
        'lessons': {for (final e in lessons.entries) e.key: e.value.toMap()},
        'txIds': txIds.toList(),
        'totalPoints': totalPoints,
        'daily': {
          for (final e in daily.entries)
            e.key: {'passed': e.value.passed, 'points': e.value.points},
        },
        'mistakes': [
          for (final m in mistakes) {...m.toMap(), 'id': m.id},
        ],
      };
}
