import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/lesson.dart';
import '../../domain/lesson_picker.dart';
import '../../domain/scoring/progression.dart';
import '../../providers/providers.dart';

/// Summary shown after all nine questions of a lesson are passed.
class LessonResultScreen extends ConsumerWidget {
  const LessonResultScreen({super.key, required this.lessonId});

  final String lessonId;

  static const _colors = {
    Activity.speaking: AppColors.speaking,
    Activity.listening: AppColors.listening,
    Activity.writing: AppColors.writing,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final lesson = catalog.lessonById(lessonId);
    final progressAsync = ref.watch(progressMapProvider);
    final text = Theme.of(context).textTheme;

    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.search_off_rounded, title: 'Lesson not found'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lesson summary')),
      body: progressAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your progress.',
          onRetry: () => ref.invalidate(progressMapProvider),
        ),
        data: (map) {
          final p = map[lessonId];
          if (!Progression.lessonCompleted(p)) {
            return EmptyState(
              icon: Icons.lock_clock_rounded,
              title: 'Lesson not finished',
              message: 'Pass all questions in Speaking, Listening and Writing to see your summary.',
              action: FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Back to lesson'),
              ),
            );
          }

          final total = Progression.lessonPoints(p);
          final wrong = Activity.values.fold<int>(
            0,
            (s, a) => s + [
              for (var i = 0; i < Progression.questionsPerActivity; i++)
                Progression.questionOf(p, a, i).wrongAttempts,
            ].fold(0, (x, y) => x + y),
          );
          final next = LessonPicker.continueLesson(catalog, map, lesson.language);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppCard(
                gradient: AppColors.brandGradient,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events_rounded, size: 64, color: Colors.white),
                    const SizedBox(height: AppSpacing.sm),
                    Text('${lesson.title} complete!',
                        style: text.headlineSmall
                            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: AppSpacing.xs),
                    Text('${_fmt(total)} points earned in this lesson',
                        style: text.titleMedium?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final a in Activity.values) ...[
                Builder(builder: (context) {
                  final attempts = Progression.attemptsFor(p, a);
                  final accuracy = attempts == 0
                      ? 0
                      : (Progression.questionsPerActivity / attempts * 100).round();
                  return AppCard(
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: _colors[a]),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.label,
                                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                              Text('$attempts attempts  |  $accuracy% accuracy',
                                  style: text.bodySmall),
                            ],
                          ),
                        ),
                        Text('${_fmt(Progression.activityPoints(p, a))} pts',
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: AppColors.purple),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        '$wrong wrong attempt${wrong == 1 ? '' : 's'} in total'
                        '${p?.completedAt != null ? '  |  finished ${_when(p!.completedAt!)}' : ''}',
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (next != null && next.id != lessonId)
                FilledButton(
                  onPressed: () => context.pushReplacement(Routes.lesson(next.id)),
                  child: Text('Next lesson: ${next.title}'),
                ),
              if (next != null && next.id != lessonId) const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => context.go(Routes.levels(lesson.language)),
                child: const Text('Back to levels'),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  static String _when(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }
}
