import 'dart:math' as math;

import '../data/catalog/lesson_catalog.dart';
import '../data/models/lesson.dart';

/// What the two columns of the Word Match game show.
enum MatchMode {
  /// Written word  <->  Bengali meaning.
  meaning,

  /// Sound (tap to hear)  <->  written word.
  sound,

  /// Written word  <->  English meaning or definition.
  definition,
}

/// Rules of the Word Match game. Pure Dart, no Flutter, so it can be tested.
///
/// Levels 1..[levelCount] get harder: more pairs, less time per pair, and the
/// mode rotates (meaning, sound, definition). Words come from the learner's own
/// lessons, following the order of the course, so playing revises what was taught.
class MatchRules {
  MatchRules._();

  static const levelCount = 30;

  static MatchMode modeFor(int level) => switch (level % 3) {
        1 => MatchMode.meaning,
        2 => MatchMode.sound,
        _ => MatchMode.definition,
      };

  /// 3 pairs on levels 1-3, one more every three levels, at most 8.
  static int pairsFor(int level) => math.min(8, 3 + (level - 1) ~/ 3);

  /// Seconds allowed: about 16 per pair at the start, 7 per pair later.
  static int secondsFor(int level) {
    final perPair = math.max(7, 16 - level ~/ 3);
    return pairsFor(level) * perPair;
  }

  /// 3 stars with almost no mistakes, 2 with a few, 1 for just finishing.
  static int starsFor({required int mistakes, required int pairs}) {
    if (mistakes <= pairs ~/ 4) return 3;
    if (mistakes <= pairs ~/ 2) return 2;
    return 1;
  }

  /// Text on the left card of a pair (null in sound mode, where the card is a speaker).
  static String? leftLabel(MatchMode mode, LessonItem item) =>
      mode == MatchMode.sound ? null : item.target;

  /// Text on the right card of a pair.
  static String rightLabel(MatchMode mode, LessonItem item) => switch (mode) {
        MatchMode.meaning => item.meaningBn,
        MatchMode.sound => item.target,
        MatchMode.definition => item.meaningEn.isEmpty ? item.meaningBn : item.meaningEn,
      };

  /// The words for [level]: [pairsFor] items taken in course order from the
  /// chosen language and level, starting further along on higher game levels.
  /// Two items never share the same right-hand label.
  static List<LessonItem> wordsFor(
    LessonCatalog catalog, {
    required String languageId,
    required String levelId,
    required int level,
  }) {
    final all = <LessonItem>[
      for (final l in catalog.lessonsFor(languageId, levelId: levelId)) ...l.items,
    ];
    if (all.isEmpty) return const [];
    final mode = modeFor(level);
    final want = pairsFor(level);
    final start = ((level - 1) * 7) % all.length;

    final picked = <LessonItem>[];
    final seenRight = <String>{};
    final seenLeft = <String>{};
    for (var i = 0; i < all.length && picked.length < want; i++) {
      final item = all[(start + i) % all.length];
      if (seenRight.add(rightLabel(mode, item)) && seenLeft.add(item.target)) {
        picked.add(item);
      }
    }
    return picked;
  }
}
