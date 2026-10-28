enum ListeningType {
  /// Hear the item, pick its Bengali meaning.
  meaning,

  /// Hear the item, pick the word that was spoken.
  word,
}

class ListeningQuestion {
  const ListeningQuestion({
    required this.type,
    required this.index,
    required this.audioText,
    required this.prompt,
    required this.options,
    required this.correct,
  });

  final ListeningType type;
  final int index;

  /// Text sent to text-to-speech.
  final String audioText;
  final String prompt;
  final List<String> options;
  final String correct;
}
