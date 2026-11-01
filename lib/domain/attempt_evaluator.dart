import '../core/utils/answer_normalizer.dart';
import '../core/utils/text_similarity.dart';
import '../data/catalog/lesson_catalog.dart';
import '../data/models/attempt.dart';
import '../data/models/lesson.dart';
import 'scoring/scoring_policy.dart';

/// Decides whether an answer is correct. Pure Dart, no I/O.
///
/// Used by the local backend. In Firebase mode the same rules run on the
/// server (functions/src/evaluate.ts), which is the only copy that counts.
class Evaluation {
  const Evaluation({
    required this.correct,
    required this.correctAnswer,
    required this.explanation,
    this.heard,
    this.comparison,
  });

  final bool correct;
  final String correctAnswer;
  final String explanation;
  final String? heard;
  final SpeechComparison? comparison;
}

class AttemptEvaluator {
  AttemptEvaluator(this.catalog, {this.policy = ScoringPolicy.defaults});

  final LessonCatalog catalog;
  final ScoringPolicy policy;

  /// The text the learner should say or type for [activity] question [index].
  /// For listening it is the correct option. Mirrored in functions/src/evaluate.ts.
  static String expectedAnswer(LessonCatalog catalog, Lesson lesson, Activity activity, int index) {
    final spec = lesson.taskFor(activity, index);
    final item = lesson.items[spec.item];
    switch (activity) {
      case Activity.listening:
        return catalog.listeningQuestion(lesson, index).correct;
      case Activity.speaking:
        return spec.kind == TaskKind.sentenceSpeak ? _sentenceOf(item) : item.target;
      case Activity.writing:
        return _isSentenceTyping(spec.kind) ? _sentenceOf(item) : item.target;
    }
  }

  static bool _isSentenceTyping(TaskKind k) =>
      k == TaskKind.unscramble || k == TaskKind.sentenceDictation;

  static String _sentenceOf(LessonItem item) => item.sentence.isEmpty ? item.target : item.sentence;

  Evaluation evaluate(Lesson lesson, AttemptRequest req) {
    final spec = lesson.taskFor(req.activity, req.index);
    final item = lesson.items[spec.item];
    final lang = lesson.language;
    final expected = expectedAnswer(catalog, lesson, req.activity, req.index);
    final isTarget = expected == item.target;
    final alternatives = isTarget ? item.alternatives : const <String>[];

    switch (req.activity) {
      case Activity.listening:
        final q = catalog.listeningQuestion(lesson, req.index);
        final chosen = req.answer ?? '';
        final ok = chosen == q.correct;
        return Evaluation(
          correct: ok,
          correctAnswer: q.correct,
          explanation: q.kind == TaskKind.meaning
              ? '"${item.target}" means "${item.meaningBn}".'
              : (q.kind == TaskKind.word
                  ? 'The word you heard was "${item.target}" (${item.meaningBn}).'
                  : '"${item.target}" (${item.meaningBn}) is the word in: ${_sentenceOf(item)}'),
          heard: chosen,
        );

      case Activity.writing:
        final typed = req.answer ?? '';
        final ok = _isSentenceTyping(spec.kind)
            ? AnswerNormalizer.isLooseMatch(input: typed, expected: expected, language: lang)
            : AnswerNormalizer.isMatch(
                input: typed,
                expected: expected,
                alternatives: alternatives,
                language: lang,
              );
        return Evaluation(
          correct: ok,
          correctAnswer: expected,
          explanation: ok
              ? 'Well done.'
              : 'The correct answer is "$expected". ${_differenceHint(expected, typed, lang)}',
          heard: typed,
        );

      case Activity.speaking:
        final heard = req.transcript ?? '';
        if (AnswerNormalizer.normalize(heard, language: lang).isEmpty) {
          return Evaluation(
            correct: false,
            correctAnswer: expected,
            explanation: 'We did not hear anything. Check your microphone and try again.',
            heard: heard,
          );
        }
        final c = SpeechMatcher.compare(
          expected: expected,
          heard: heard,
          language: lang,
          alternatives: alternatives,
        );
        final ok = c.similarity >= policy.speakingPassSimilarity &&
            c.completeness >= policy.speakingMinCompleteness;
        return Evaluation(
          correct: ok,
          correctAnswer: expected,
          explanation: ok
              ? 'Clear speech. The recogniser understood you.'
              : (c.missing.isEmpty
                  ? 'Say it again slowly: "$expected".'
                  : 'Missing or unclear: ${c.missing.join(lang == 'ja' ? '' : ', ')}. Say "$expected" again.'),
          heard: heard,
          comparison: c,
        );
    }
  }

  /// Short, kind hint pointing at the first wrong character.
  static String _differenceHint(String expected, String typed, String lang) {
    final e = AnswerNormalizer.normalize(expected, language: lang).runes.toList();
    final t = AnswerNormalizer.normalize(typed, language: lang).runes.toList();
    if (t.isEmpty) return 'Type what you hear.';
    var i = 0;
    while (i < e.length && i < t.length && e[i] == t[i]) {
      i++;
    }
    if (i >= e.length) return 'You typed extra characters at the end.';
    if (i >= t.length) return 'Your answer ends too early.';
    return 'Your answer first differs at character ${i + 1}.';
  }
}
