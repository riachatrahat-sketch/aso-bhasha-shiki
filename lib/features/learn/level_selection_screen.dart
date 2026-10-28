import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../domain/lesson_picker.dart';
import '../../providers/providers.dart';

class LevelSelectionScreen extends ConsumerWidget {
  const LevelSelectionScreen({super.key, required this.languageId});

  final String languageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final language = catalog.language(languageId);
    final progressAsync = ref.watch(progressMapProvider);
    final text = Theme.of(context).textTheme;

    if (language == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.search_off_rounded, title: 'Language not found'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('${language.flag}  ${language.name} levels')),
      body: progressAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your progress.',
          onRetry: () => ref.invalidate(progressMapProvider),
        ),
        data: (progress) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            for (final level in language.levels) ...[
              Builder(builder: (context) {
                final count = catalog.lessonsFor(languageId, levelId: level.id).length;
                final available = count > 0;
                final totals =
                    LessonPicker.languageTotals(catalog, progress, languageId, levelId: level.id);
                return Opacity(
                  opacity: available ? 1 : 0.55,
                  child: AppCard(
                    onTap: available
                        ? () => context.push(Routes.lessons(languageId, level.id))
                        : null,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Icon(
                            available ? Icons.school_rounded : Icons.lock_outline_rounded,
                            color: AppColors.blue,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(level.name,
                                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                available
                                    ? '$count lesson${count == 1 ? '' : 's'}  |  ${totals.passed}/${totals.total} passed'
                                    : 'Coming soon',
                                style: text.bodySmall,
                              ),
                              if (available) ...[
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: totals.total == 0 ? 0 : totals.passed / totals.total,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}
