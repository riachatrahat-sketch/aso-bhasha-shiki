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

class LessonItem {
  const LessonItem({
    required this.target,
    required this.meaningBn,
    required this.meaningEn,
    required this.example,
    this.reading,
    this.alternatives = const [],
  });

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
  });

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
      );
}

class LevelInfo {
  const LevelInfo({required this.id, required this.name});
  final String id;
  final String name;
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
              return LevelInfo(id: m['id'] as String, name: m['name'] as String);
            })
            .toList(),
      );
}
