import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../domain/lesson_picker.dart';
import '../../providers/providers.dart';

/// "Learn" tab: pick English or Japanese.
class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final progressAsync = ref.watch(progressMapProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a language')),
      body: progressAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your progress.',
          onRetry: () => ref.invalidate(progressMapProvider),
        ),
        data: (progress) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            for (final lang in catalog.languages) ...[
              Builder(builder: (context) {
                final totals = LessonPicker.languageTotals(catalog, progress, lang.id);
                final lessons = catalog.lessonsFor(lang.id).length;
                return AppCard(
                  onTap: () => context.push(Routes.levels(lang.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(lang.flag, style: const TextStyle(fontSize: 44)),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Learn ${lang.name}',
                                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  '${lang.levels.length} levels  |  $lessons lessons available',
                                  style: text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      LinearProgressIndicator(
                        value: totals.total == 0 ? 0 : totals.passed / totals.total,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 6),
                      Text('${totals.passed}/${totals.total} questions passed',
                          style: text.bodySmall),
                    ],
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
