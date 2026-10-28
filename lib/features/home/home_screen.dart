import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/lesson.dart';
import '../../domain/lesson_picker.dart';
import '../../domain/scoring/progression.dart';
import '../../domain/scoring/scoring_engine.dart';
import '../../domain/scoring/scoring_policy.dart';
import '../../providers/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _activityStyle = {
    Activity.speaking: (Icons.record_voice_over_rounded, AppColors.speaking,
        'Read aloud and get feedback on your speech.'),
    Activity.listening: (Icons.headphones_rounded, AppColors.listening,
        'Listen carefully and choose the right answer.'),
    Activity.writing: (Icons.edit_rounded, AppColors.writing,
        'Type exactly what you hear.'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final catalog = ref.watch(catalogProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final progressAsync = ref.watch(progressMapProvider);
    final stats = ref.watch(statsProvider).valueOrNull;

    if (progressAsync.hasError) {
      return ErrorView(
        message: 'Could not load your progress. Check your connection.',
        onRetry: () => ref.invalidate(progressMapProvider),
      );
    }
    final progress = progressAsync.valueOrNull;
    if (progress == null) return const LoadingView();

    final language = profile?.preferredLanguage ?? 'en';
    final goal = profile?.dailyGoal ?? 5;
    final today = ref.watch(todayPassedProvider);
    final streak = ref.watch(streakProvider);
    final points = ScoringEngine.displayTotal(stats?.totalPoints ?? 0, ScoringPolicy.defaults);
    final lessonsDone = progress.values.where((p) => p.completed).length;

    final continueLesson = LessonPicker.continueLesson(catalog, progress, language);
    final challenge = LessonPicker.dailyChallenge(catalog, progress, language, DateTime.now());

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Hello, ${profile?.firstName ?? 'Learner'}!',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          Text('Ready to learn something new today?', style: text.bodyMedium),
          const SizedBox(height: AppSpacing.lg),

          // Daily goal + stats
          AppCard(
            child: Row(
              children: [
                ProgressRing(
                  value: goal == 0 ? 0 : today / goal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$today/$goal',
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text('today', style: text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily goal',
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        today >= goal
                            ? 'Goal reached. Great work!'
                            : 'Pass ${goal - today} more question${goal - today == 1 ? '' : 's'} today.',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.local_fire_department_rounded,
                  value: '$streak',
                  label: 'Day streak',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatTile(
                  icon: Icons.stars_rounded,
                  value: _fmt(points),
                  label: 'Points',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatTile(
                  icon: Icons.check_circle_rounded,
                  value: '$lessonsDone',
                  label: 'Lessons',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Languages
          const SectionTitle('Choose a language'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final lang in catalog.languages) ...[
                Expanded(
                  child: AppCard(
                    onTap: () => context.push(Routes.levels(lang.id)),
                    child: Column(
                      children: [
                        Text(lang.flag, style: const TextStyle(fontSize: 36)),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Learn ${lang.name}',
                            textAlign: TextAlign.center,
                            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                if (lang != catalog.languages.last) const SizedBox(width: AppSpacing.md),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Activities
          SectionTitle(
            'Practice',
            trailing: Text(catalog.language(language)?.name ?? '', style: text.bodySmall),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final activity in Activity.values) ...[
            Builder(builder: (context) {
              final style = _activityStyle[activity]!;
              final totals = LessonPicker.activityTotals(catalog, progress, language, activity);
              final next = LessonPicker.nextForActivity(catalog, progress, language, activity);
              return _ActivityCard(
                icon: style.$1,
                color: style.$2,
                title: activity.label,
                description: style.$3,
                value: totals.total == 0 ? 0 : totals.passed / totals.total,
                caption: '${totals.passed}/${totals.total} questions',
                buttonLabel: next == null
                    ? 'All done'
                    : (totals.passed == 0 ? 'Start' : 'Continue'),
                onPressed: next == null
                    ? null
                    : () => context.push(Routes.activity(next.id, activity.name)),
              );
            }),
            const SizedBox(height: AppSpacing.md),
          ],

          // Continue learning
          const SizedBox(height: AppSpacing.sm),
          const SectionTitle('Continue learning'),
          const SizedBox(height: AppSpacing.sm),
          if (continueLesson == null)
            const AppCard(child: Text('You finished every lesson. New lessons are coming soon!'))
          else
            AppCard(
              onTap: () => context.push(Routes.lesson(continueLesson.id)),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_fill_rounded, size: 40, color: AppColors.blue),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(continueLesson.title,
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: LessonPicker.passedInLesson(progress[continueLesson.id]) /
                              Progression.questionsPerLesson,
                          borderRadius: BorderRadius.circular(8),
                          minHeight: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          // Daily challenge
          const SectionTitle('Daily challenge'),
          const SizedBox(height: AppSpacing.sm),
          if (challenge == null)
            const AppCard(child: Text('No challenge today. You completed everything!'))
          else
            AppCard(
              gradient: AppColors.brandGradient,
              onTap: () => context.push(Routes.lesson(challenge.id)),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 36),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Finish "${challenge.title}"',
                            style: text.titleMedium
                                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                        Text('Pass all 9 questions today.',
                            style: text.bodySmall?.copyWith(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      child: Column(
        children: [
          Icon(icon, color: AppColors.purple),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.value,
    required this.caption,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final double value;
  final String caption;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(description, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LinearProgressIndicator(
            value: value,
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: Text(caption, style: text.bodySmall)),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  minimumSize: const Size(120, 44),
                ),
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
