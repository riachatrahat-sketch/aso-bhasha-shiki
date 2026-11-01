import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/utils/json_helpers.dart';
import '../models/lesson.dart';
import '../models/question.dart';

/// All languages, levels and lessons, loaded from assets/content/lessons.json.
///
/// To add content, edit that JSON file (and re-run the seed script so the
/// Cloud Function sees it). No Dart changes are needed.
class LessonCatalog {
  LessonCatalog({required this.languages, required this.lessons});

  final List<LanguageInfo> languages;
  final List<Lesson> lessons;

  factory LessonCatalog.fromJson(Map<String, dynamic> json) => LessonCatalog(
        languages: (json['languages'] as List)
            .map((e) => LanguageInfo.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        lessons: (json['lessons'] as List)
            .map((e) => Lesson.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  static Future<LessonCatalog> load(AssetBundle bundle) async {
    final raw = await bundle.loadString('assets/content/lessons.json');
    return LessonCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  LanguageInfo? language(String id) {
    for (final l in languages) {
      if (l.id == id) return l;
    }
    return null;
  }

  Lesson? lessonById(String id) {
    for (final l in lessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Lessons of a language (optionally one level), in teaching order.
  List<Lesson> lessonsFor(String languageId, {String? levelId}) {
    final levelOrder = {
      for (final lang in languages)
        if (lang.id == languageId)
          for (var i = 0; i < lang.levels.length; i++) lang.levels[i].id: i,
    };
    final result = lessons
        .where((l) => l.language == languageId && (levelId == null || l.level == levelId))
        .toList()
      ..sort((a, b) {
        final byLevel = (levelOrder[a.level] ?? 0).compareTo(levelOrder[b.level] ?? 0);
        return byLevel != 0 ? byLevel : a.order.compareTo(b.order);
      });
    return result;
  }

  /// Builds listening question [index] of [lesson] from the lesson's task plan.
  ///
  /// meaning:       hear the word, choose its Bengali meaning.
  /// word:          hear the word, choose the word.
  /// sentenceBlank: hear a sentence (shown with a blank), choose the missing word.
  /// sentenceWord:  hear a sentence, choose the target word used in it.
  /// This rule is mirrored in functions/src/evaluate.ts (listeningCorrectAnswer).
  ///
  /// Wrong options come from other items of the same language, preferring ones
  /// of a similar length, and are ordered by a stable hash so a question always
  /// looks the same. Harder lessons (tier 4 and 5) show five options.
  ListeningQuestion listeningQuestion(Lesson lesson, int index) {
    final spec = lesson.taskFor(Activity.listening, index);
    final item = lesson.items[spec.item];
    final kind = spec.kind;
    final byMeaning = kind == TaskKind.meaning;
    final correct = byMeaning ? item.meaningBn : item.target;

    final pool = <String>{
      for (final l in lessonsFor(lesson.language))
        for (final i in l.items) byMeaning ? i.meaningBn : i.target,
    }..remove(correct);

    int shape(String s) => lesson.language == 'ja' ? s.runes.length ~/ 3 : s.split(' ').length;
    final sameShape = pool.where((s) => shape(s) == shape(correct)).toList();
    final wrongCount = lesson.tier >= 4 ? 4 : 3;
    final candidates = sameShape.length >= wrongCount * 3 ? sameShape : pool.toList();

    int rank(String s) => stableHash('${lesson.id}#$index#$s');
    final wrong = candidates..sort((a, b) => rank(a).compareTo(rank(b)));
    final options = [correct, ...wrong.take(wrongCount)]..sort((a, b) => rank(a).compareTo(rank(b)));

    final sentenceKind = kind == TaskKind.sentenceBlank || kind == TaskKind.sentenceWord;
    final sentence = item.sentence.isEmpty ? item.target : item.sentence;

    return ListeningQuestion(
      kind: kind,
      index: index,
      audioText: sentenceKind ? sentence : item.target,
      displayText: kind == TaskKind.sentenceBlank ? item.cloze : null,
      prompt: switch (kind) {
        TaskKind.meaning => 'What does it mean?',
        TaskKind.sentenceBlank => 'Listen. Which word fills the blank?',
        TaskKind.sentenceWord => 'Listen to the sentence. Which word is used in it?',
        _ => 'Which word did you hear?',
      },
      options: options,
      correct: correct,
    );
  }
}
