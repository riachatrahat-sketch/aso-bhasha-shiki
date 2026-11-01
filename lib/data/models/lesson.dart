/// The three learning activities every lesson contains.
enum Activity { speaking, listening, writing }

extension ActivityX on Activity {
  String get label => switch (this) {
        Activity.speaking => 'Reading & Speaking',
        Activity.listening => 'Listening Practice',
        Activity.writing => 'Writing Practice',
      };

  String get shortLabel => switch (this) {
        Activity.speaking => 'Speaking',
        Activity.listening => 'Listening',
        Activity.writing => 'Writing',
      };

  static Activity parse(String name) =>
      Activity.values.firstWhere((a) => a.name == name, orElse: () => Activity.speaking);
}

/// What a single question asks the learner to do.
///
/// Decided by tools/build_lessons.py and stored in each lesson's "tasks" field,
/// so the app and the Cloud Function never have to re-implement the rules.
enum TaskKind {
  // Speaking
  readAloud, // read the word shown
  translateSpeak, // see the Bengali meaning, say the word
  sentenceSpeak, // read the whole example sentence

  // Listening
  meaning, // hear the word, pick its Bengali meaning
  word, // hear the word, pick the word
  sentenceBlank, // hear a sentence with a blank shown, pick the missing word
  sentenceWord, // hear a sentence, pick the target word used in it

  // Writing
  dictation, // hear the word, type it
  translateType, // see the Bengali meaning, type the word
  cloze, // type the missing word of a sentence
  unscramble, // put the words of a sentence in order
  sentenceDictation; // hear a sentence, type all of it

  static TaskKind? tryParse(String? name) {
    for (final k in TaskKind.values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// One planned question: which kind, and which of the lesson's three items it uses.
class TaskSpec {
  const TaskSpec(this.kind, this.item);

  final TaskKind kind;
  final int item;
}

class LessonItem {
  const LessonItem({
    required this.target,
    required this.meaningBn,
    required this.meaningEn,
    required this.example,
    this.sentence = '',
    this.cloze,
    this.emoji,
    this.reading,
    this.alternatives = const [],
  });

  /// The example sentence in the target language (no translation).
  final String sentence;

  /// [sentence] with the target replaced by a blank, or null if that is not possible.
  final String? cloze;

  /// A picture for young learners (kids levels), or null.
  final String? emoji;

  /// The word or sentence the learner works with.
  final String target;

  /// Romaji for Japanese items, null for English.
  final String? reading;

  final String meaningBn;
  final String meaningEn;
  final String example;

  /// Other accepted spellings (for example the kanji form of a kana word).
  final List<String> alternatives;

  factory LessonItem.fromJson(Map<String, dynamic> j) => LessonItem(
        target: j['target'] as String,
        reading: j['reading'] as String?,
        meaningBn: j['meaningBn'] as String,
        meaningEn: j['meaningEn'] as String? ?? '',
        example: j['example'] as String? ?? '',
        sentence: j['sentence'] as String? ?? '',
        cloze: j['cloze'] as String?,
        emoji: j['emoji'] as String?,
        alternatives: ((j['alternatives'] as List?) ?? const []).cast<String>(),
      );
}

class Lesson {
  const Lesson({
    required this.id,
    required this.language,
    required this.level,
    required this.order,
    required this.title,
    required this.difficulty,
    required this.items,
    this.tier = 1,
    this.tasks = const {},
  });

  /// 1 (easiest) to 5 (hardest). Rises through a level and from level to level.
  final int tier;

  /// Planned questions per activity name ("speaking", "listening", "writing").
  /// Empty for old content: every question then uses the classic task.
  final Map<String, List<TaskSpec>> tasks;

  /// The question [index] of [activity].
  TaskSpec taskFor(Activity activity, int index) {
    final list = tasks[activity.name];
    if (list != null && index >= 0 && index < list.length) return list[index];
    final kind = switch (activity) {
      Activity.speaking => TaskKind.readAloud,
      Activity.listening => index.isEven ? TaskKind.meaning : TaskKind.word,
      Activity.writing => TaskKind.dictation,
    };
    return TaskSpec(kind, index);
  }

  final String id;
  final String language;
  final String level;
  final int order;
  final String title;

  /// 1 (easy) to 3 (hard).
  final int difficulty;

  /// Exactly three items. Item i is used for question i of every activity.
  final List<LessonItem> items;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as String,
        language: j['language'] as String,
        level: j['level'] as String,
        order: (j['order'] as num).toInt(),
        title: j['title'] as String,
        difficulty: (j['difficulty'] as num?)?.toInt() ?? 1,
        items: (j['items'] as List)
            .map((e) => LessonItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        tier: (j['tier'] as num?)?.toInt() ?? 1,
        tasks: _parseTasks(j['tasks']),
      );

  static Map<String, List<TaskSpec>> _parseTasks(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, List<TaskSpec>>{};
    raw.forEach((key, value) {
      if (value is! List) return;
      out[key as String] = [
        for (final e in value)
          TaskSpec(
            TaskKind.tryParse((e as Map)['kind'] as String?) ?? TaskKind.readAloud,
            ((e)['item'] as num?)?.toInt() ?? 0,
          ),
      ];
    });
    return out;
  }
}

class LevelInfo {
  const LevelInfo({required this.id, required this.name, this.audience = 'all'});
  final String id;
  final String name;

  /// "kids" for levels made for young children, otherwise "all".
  final String audience;

  bool get isKids => audience == 'kids';
}

class LanguageInfo {
  const LanguageInfo({
    required this.id,
    required this.name,
    required this.flag,
    required this.ttsLocale,
    required this.sttLocale,
    required this.levels,
  });

  final String id;
  final String name;
  final String flag;

  /// Locale for text-to-speech, e.g. en-US.
  final String ttsLocale;

  /// Locale for speech recognition, e.g. en_US.
  final String sttLocale;
  final List<LevelInfo> levels;

  factory LanguageInfo.fromJson(Map<String, dynamic> j) => LanguageInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        flag: j['flag'] as String,
        ttsLocale: j['ttsLocale'] as String,
        sttLocale: j['sttLocale'] as String,
        levels: (j['levels'] as List)
            .map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              return LevelInfo(
                id: m['id'] as String,
                name: m['name'] as String,
                audience: (m['audience'] as String?) ?? 'all',
              );
            })
            .toList(),
      );
}
