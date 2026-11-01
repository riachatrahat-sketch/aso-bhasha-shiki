import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/match_game.dart';
import '../settings/theme_controller.dart';

/// Stars (0-3) won on each Word Match level, kept on the device.
/// Key: "<language>/<level>" -> list of [MatchRules.levelCount] star counts.
class GameProgress extends Notifier<Map<String, List<int>>> {
  static const _key = 'match_game_stars';

  @override
  Map<String, List<int>> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in decoded.entries) e.key: (e.value as List).cast<num>().map((n) => n.toInt()).toList(),
      };
    } catch (_) {
      return {};
    }
  }

  static String deckKey(String languageId, String levelId) => '$languageId/$levelId';

  /// Stars for [level] (1-based) of a deck.
  int stars(String languageId, String levelId, int level) {
    final list = state[deckKey(languageId, levelId)];
    if (list == null || level < 1 || level > list.length) return 0;
    return list[level - 1];
  }

  /// A level is open when it is the first one or the previous level has a star.
  bool isUnlocked(String languageId, String levelId, int level) =>
      level <= 1 || stars(languageId, levelId, level - 1) > 0;

  /// Keeps the best result.
  Future<void> record(String languageId, String levelId, int level, int stars) async {
    final key = deckKey(languageId, levelId);
    final list = List<int>.from(state[key] ?? List<int>.filled(MatchRules.levelCount, 0));
    while (list.length < MatchRules.levelCount) {
      list.add(0);
    }
    if (stars > list[level - 1]) list[level - 1] = stars;
    state = {...state, key: list};
    await ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(state));
  }
}

final gameProgressProvider =
    NotifierProvider<GameProgress, Map<String, List<int>>>(GameProgress.new);
