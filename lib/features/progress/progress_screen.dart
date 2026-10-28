import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/lesson.dart';
import '../../domain/lesson_picker.dart';
import '../../domain/progress_insights.dart';
import '../../domain/scoring/scoring_engine.dart';
import '../../domain/scoring/scoring_policy.dart';
import '../../providers/providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  static const _colors = {
    Activity.speaking: AppColors.speaking,
    Activity.listening: AppColors.listening,
    Activity.writing: AppColors.writing,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final progressAsync = ref.watch(progressMapProvider);
    final daily = ref.watch(dailyProvider).valueOrNull ?? const [];
    final stats = ref.watch(statsProvider).valueOrNull;
    final mistakes = ref.watch(mistakesProvider).valueOrNull ?? const [];
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final streak = ref.watch(streakProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Your progress')),
      body: progressAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your progress.',
          onRetry: () => ref.invalidate(progressMapProvider),
        ),
        data: (progress) {
          final points =
              ScoringEngine.displayTotal(stats?.totalPoints ?? 0, ScoringPolicy.defaults);
          final lessonsDone = progress.values.where((p) => p.completed).length;
          final week = ProgressInsights.lastDays(daily, DateTime.now());
          final recs = ProgressInsights.recommendations(
            catalog,
            progress,
            profile?.preferredLanguage ?? 'en',
          );
          final maxY = week.fold<int>(0, (m, d) => d.passed > m ? d.passed : m);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Row(
                children: [
                  Expanded(child: _Big(icon: Icons.stars_rounded, value: _fmt(points), label: 'Total points')),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _Big(icon: Icons.check_circle_rounded, value: '$lessonsDone', label: 'Lessons done')),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _Big(icon: Icons.local_fire_department_rounded, value: '$streak', label: 'Day streak')),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              const SectionTitle('Accuracy'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: [
                    for (final a in Activity.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _AccuracyRow(
                          label: a.shortLabel,
                          value: ProgressInsights.accuracy(progress, a),
                          color: _colors[a]!,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Accuracy = questions passed divided by attempts. '
                      'Passing first time gives 100%.',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              const SectionTitle('This week'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: SizedBox(
                  height: 180,
                  child: BarChart(
                    BarChartData(
                      maxY: (maxY < 5 ? 5 : maxY + 1).toDouble(),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= week.length) return const SizedBox.shrink();
                              final d = DateTime.parse(week[i].date);
                              const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(names[d.weekday - 1], style: text.labelSmall),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < week.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: week[i].passed.toDouble(),
                                width: 18,
                                borderRadius: BorderRadius.circular(6),
                                gradient: AppColors.brandGradient,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Questions passed per day', style: text.bodySmall),
              ),
              const SizedBox(height: AppSpacing.lg),

              const SectionTitle('By language'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: [
                    for (final lang in catalog.languages)
                      Builder(builder: (context) {
                        final t = LessonPicker.languageTotals(catalog, progress, lang.id);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Text(lang.flag, style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(lang.name, style: text.titleSmall),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: t.total == 0 ? 0 : t.passed / t.total,
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text('${t.passed}/${t.total}', style: text.bodySmall),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              SectionTitle(
                'Recent mistakes',
                trailing: mistakes.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => context.push(Routes.mistakes),
                        child: const Text('See all'),
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (mistakes.isEmpty)
                const AppCard(child: Text('No mistakes yet. Keep going!'))
              else
                for (final m in mistakes.take(3)) ...[
                  AppCard(
                    onTap: () => context.push(Routes.lesson(m.lessonId)),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.expected,
                                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              Text(m.activity.shortLabel, style: text.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              const SizedBox(height: AppSpacing.md),

              const SectionTitle('Recommended for you'),
              const SizedBox(height: AppSpacing.sm),
              if (recs.isEmpty)
                const AppCard(child: Text('You finished every available lesson. Well done!'))
              else
                for (final r in recs) ...[
                  AppCard(
                    onTap: () => context.push(Routes.activity(r.lesson.id, r.activity.name)),
                    child: Row(
                      children: [
                        Icon(Icons.flag_rounded, color: _colors[r.activity]),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.lesson.title,
                                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              Text('Practise ${r.activity.shortLabel.toLowerCase()}',
                                  style: text.bodySmall),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          );
        },
      ),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _Big extends StatelessWidget {
  const _Big({required this.icon, required this.value, required this.label});

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
          const SizedBox(height: 4),
          Text(value, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: text.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _AccuracyRow extends StatelessWidget {
  const _AccuracyRow({required this.label, required this.value, required this.color});

  final String label;
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(width: 82, child: Text(label, style: text.bodyMedium)),
        Expanded(
          child: LinearProgressIndicator(
            value: value ?? 0,
            color: color,
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            value == null ? 'n/a' : '${(value! * 100).round()}%',
            textAlign: TextAlign.end,
            style: text.labelLarge,
          ),
        ),
      ],
    );
  }
}
