import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../providers/providers.dart';

class MistakesScreen extends ConsumerWidget {
  const MistakesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mistakesProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mistakes review')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your mistakes.',
          onRetry: () => ref.invalidate(mistakesProvider),
        ),
        data: (mistakes) {
          if (mistakes.isEmpty) {
            return const EmptyState(
              icon: Icons.sentiment_satisfied_alt_rounded,
              title: 'No mistakes yet',
              message: 'When you answer something wrongly, it will show up here so you can review it.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: mistakes.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final m = mistakes[i];
              final lesson = ref.read(catalogProvider).lessonById(m.lessonId);
              return AppCard(
                onTap: () => context.push(Routes.lesson(m.lessonId)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Chip(
                          label: Text(m.activity.shortLabel),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(lesson?.title ?? m.lessonId,
                              style: text.bodySmall, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Correct: ${m.expected}',
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    if (m.given.isNotEmpty)
                      Text('Your answer: ${m.given}',
                          style: text.bodyMedium
                              ?.copyWith(color: Theme.of(context).colorScheme.error)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
