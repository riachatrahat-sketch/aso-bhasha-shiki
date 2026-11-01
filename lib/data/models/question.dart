import 'lesson.dart';

/// A listening question, fully built and ready to show.
class ListeningQuestion {
  const ListeningQuestion({
    required this.kind,
    required this.index,
    required this.audioText,
    required this.prompt,
    required this.options,
    required this.correct,
    this.displayText,
  });

  /// meaning, word, sentenceBlank or sentenceWord.
  final TaskKind kind;
  final int index;

  /// Text sent to text-to-speech (a word or a whole sentence).
  final String audioText;
  final String prompt;

  /// Text shown on screen, for example the sentence with a blank.
  final String? displayText;
  final List<String> options;
  final String correct;

  /// True when the options are Bengali meanings, false when they are words.
  bool get optionsAreMeanings => kind == TaskKind.meaning;
}
