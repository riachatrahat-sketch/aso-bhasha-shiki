import '../core/utils/answer_normalizer.dart';
import '../core/utils/text_similarity.dart';
import '../data/catalog/lesson_catalog.dart';
import '../data/models/attempt.dart';
import '../data/models/lesson.dart';
import '../data/models/question.dart';
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

  Evaluation evaluate(Lesson lesson, AttemptRequest req) {
    final item = lesson.items[req.index];
    final lang = lesson.language;

    switch (req.activity) {
      case Activity.listening:
        final q = catalog.listeningQuestion(lesson, req.index);
        final chosen = req.answer ?? '';
        final ok = chosen == q.correct;
        return Evaluation(
          correct: ok,
          correctAnswer: q.correct,
          explanation: q.type == ListeningType.meaning
              ? '"${item.target}" means "${item.meaningBn}".'
              : 'The word you heard was "${item.target}" (${item.meaningBn}).',
          heard: chosen,
        );

      case Activity.writing:
        final typed = req.answer ?? '';
        final ok = AnswerNormalizer.isMatch(
          input: typed,
          expected: item.target,
          alternatives: item.alternatives,
          language: lang,
        );
        return Evaluation(
          correct: ok,
          correctAnswer: item.target,
          explanation: ok
              ? 'Well done.'
              : 'The correct spelling is "${item.target}". ${_differenceHint(item.target, typed, lang)}',
          heard: typed,
        );

      case Activity.speaking:
        final heard = req.transcript ?? '';
        if (AnswerNormalizer.normalize(heard, language: lang).isEmpty) {
          return Evaluation(
            correct: false,
            correctAnswer: item.target,
            explanation: 'We did not hear anything. Check your microphone and try again.',
            heard: heard,
          );
        }
        final c = SpeechMatcher.compare(
          expected: item.target,
          heard: heard,
          language: lang,
          alternatives: item.alternatives,
        );
        final ok = c.similarity >= policy.speakingPassSimilarity &&
            c.completeness >= policy.speakingMinCompleteness;
        return Evaluation(
          correct: ok,
          correctAnswer: item.target,
          explanation: ok
              ? 'Clear speech. The recogniser understood you.'
              : (c.missing.isEmpty
                  ? 'Say it again slowly: "${item.target}".'
                  : 'Missing or unclear: ${c.missing.join(lang == 'ja' ? '' : ', ')}. Say "${item.target}" again.'),
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
