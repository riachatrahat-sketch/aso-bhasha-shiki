import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../domain/lesson_picker.dart';
import '../../domain/scoring/progression.dart';
import '../../providers/providers.dart';

class LessonListScreen extends ConsumerWidget {
  const LessonListScreen({super.key, required this.languageId, required this.levelId});

  final String languageId;
  final String levelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final lessons = catalog.lessonsFor(languageId, levelId: levelId);
    final levelName = catalog
            .language(languageId)
            ?.levels
            .where((l) => l.id == levelId)
            .map((l) => l.name)
            .firstOrNull ??
        'Lessons';
    final progressAsync = ref.watch(progressMapProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(levelName)),
      body: progressAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your progress.',
          onRetry: () => ref.invalidate(progressMapProvider),
        ),
        data: (progress) {
          if (lessons.isEmpty) {
            return const EmptyState(
              icon: Icons.hourglass_empty_rounded,
              title: 'No lessons yet',
              message: 'Lessons for this level are coming soon.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: lessons.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) {
              final lesson = lessons[i];
              final p = progress[lesson.id];
              final passed = LessonPicker.passedInLesson(p);
              final done = Progression.lessonCompleted(p);
              return AppCard(
                onTap: () => context.push(Routes.lesson(lesson.id)),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: done
                          ? AppColors.writing.withValues(alpha: 0.15)
                          : AppColors.blue.withValues(alpha: 0.12),
                      child: done
                          ? const Icon(Icons.check_rounded, color: AppColors.writing)
                          : Text('${i + 1}',
                              style: const TextStyle(
                                  color: AppColors.blue, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lesson.title,
                              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              for (var d = 1; d <= 3; d++)
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: d <= lesson.difficulty
                                      ? AppColors.purple
                                      : AppColors.purple.withValues(alpha: 0.2),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                done
                                    ? 'Completed'
                                    : (passed == 0
                                        ? 'Not started'
                                        : '$passed/${Progression.questionsPerLesson} passed'),
                                style: text.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
