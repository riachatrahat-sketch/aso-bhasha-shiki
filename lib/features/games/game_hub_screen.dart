import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../domain/match_game.dart';
import '../../providers/providers.dart';
import 'game_progress.dart';

/// Pick a language and a word set, then pick a Word Match level.
class GameHubScreen extends ConsumerStatefulWidget {
  const GameHubScreen({super.key});

  @override
  ConsumerState<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends ConsumerState<GameHubScreen> {
  String? _language;
  String? _level;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    ref.watch(gameProgressProvider); // rebuild when stars change
    final text = Theme.of(context).textTheme;

    final languageId = _language ?? profile?.preferredLanguage ?? catalog.languages.first.id;
    final language = catalog.language(languageId) ?? catalog.languages.first;
    final decks = [
      for (final l in language.levels)
        if (catalog.lessonsFor(language.id, levelId: l.id).isNotEmpty) l,
    ];
    final deck = decks.firstWhere(
      (l) => l.id == _level,
      orElse: () => decks.first,
    );

    final stars = [
      for (var n = 1; n <= MatchRules.levelCount; n++)
        ref.read(gameProgressProvider.notifier).stars(language.id, deck.id, n),
    ];
    final totalStars = stars.fold(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: const Text('Word Match')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            gradient: AppColors.brandGradient,
            child: Row(
              children: [
                const Text('🎮', style: TextStyle(fontSize: 40)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Match each word with its meaning or its sound before time runs out. '
                    'Every level is harder than the last one.',
                    style: text.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionTitle('Language'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            children: [
              for (final l in catalog.languages)
                ChoiceChip(
                  label: Text('${l.flag} ${l.name}'),
                  selected: l.id == language.id,
                  onSelected: (_) => setState(() {
                    _language = l.id;
                    _level = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const SectionTitle('Words from'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final l in decks)
                ChoiceChip(
                  label: Text(l.isKids ? '${l.name} (kids)' : l.name),
                  selected: l.id == deck.id,
                  onSelected: (_) => setState(() => _level = l.id),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionTitle(
            'Levels',
            trailing: Text('$totalStars / ${MatchRules.levelCount * 3} stars', style: text.bodyMedium),
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var n = 1; n <= MatchRules.levelCount; n++)
                _LevelTile(
                  number: n,
                  stars: stars[n - 1],
                  unlocked: n == 1 || stars[n - 2] > 0,
                  onTap: () => context.push(Routes.matchGame(language.id, deck.id, n)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Level 1 starts easy: 3 pairs and lots of time. '
            'Win at least one star to open the next level.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.number,
    required this.stars,
    required this.unlocked,
    required this.onTap,
  });

  final int number;
  final int stars;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: unlocked ? AppColors.blue.withValues(alpha: 0.12) : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        onTap: unlocked ? onTap : null,
        child: Center(
          child: unlocked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$number',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text('★' * stars + '☆' * (3 - stars),
                        style: const TextStyle(fontSize: 11, color: Colors.amber)),
                  ],
                )
              : const Icon(Icons.lock_outline_rounded, size: 20),
        ),
      ),
    );
  }
}
