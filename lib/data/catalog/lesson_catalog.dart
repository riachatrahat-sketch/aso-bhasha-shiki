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

  /// Builds listening question [index] of [lesson].
  ///
  /// Even indexes (0, 2): hear the item, choose its Bengali meaning.
  /// Odd indexes (1):     hear the item, choose the word that was spoken.
  /// This rule is mirrored in functions/src/lessons.ts.
  ///
  /// Wrong options are taken from other items of the same language and ordered
  /// by a stable hash so a question always looks the same.
  ListeningQuestion listeningQuestion(Lesson lesson, int index) {
    final item = lesson.items[index];
    final type = index.isEven ? ListeningType.meaning : ListeningType.word;
    final correct = type == ListeningType.meaning ? item.meaningBn : item.target;

    final pool = <String>{
      for (final l in lessonsFor(lesson.language))
        for (final i in l.items) type == ListeningType.meaning ? i.meaningBn : i.target,
    }..remove(correct);

    int rank(String s) => stableHash('${lesson.id}#$index#$s');
    final wrong = pool.toList()..sort((a, b) => rank(a).compareTo(rank(b)));
    final options = [correct, ...wrong.take(3)]..sort((a, b) => rank(a).compareTo(rank(b)));

    return ListeningQuestion(
      type: type,
      index: index,
      audioText: item.target,
      prompt: type == ListeningType.meaning
          ? 'What does it mean?'
          : 'Which word did you hear?',
      options: options,
      correct: correct,
    );
  }
}
