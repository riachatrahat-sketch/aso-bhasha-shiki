import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/lesson.dart';
import '../../domain/scoring/progression.dart';
import '../../providers/providers.dart';

class LessonDetailScreen extends ConsumerWidget {
  const LessonDetailScreen({super.key, required this.lessonId});

  final String lessonId;

  static const _icons = {
    Activity.speaking: (Icons.record_voice_over_rounded, AppColors.speaking),
    Activity.listening: (Icons.headphones_rounded, AppColors.listening),
    Activity.writing: (Icons.edit_rounded, AppColors.writing),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    final lesson = catalog.lessonById(lessonId);
    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.search_off_rounded, title: 'Lesson not found'),
      );
    }
    final language = catalog.language(lesson.language)!;
    final progressAsync = ref.watch(progressMapProvider);
    final p = ref.watch(lessonProgressProvider(lessonId));
    final text = Theme.of(context).textTheme;
    final done = Progression.lessonCompleted(p);

    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: progressAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your progress.',
          onRetry: () => ref.invalidate(progressMapProvider),
        ),
        data: (_) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (done)
              AppCard(
                gradient: AppColors.brandGradient,
                onTap: () => context.push(Routes.result(lessonId)),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 36),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text('Lesson complete! Tap to see your summary.',
                          style: text.titleSmall?.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            if (done) const SizedBox(height: AppSpacing.md),

            const SectionTitle('Words and sentences'),
            const SizedBox(height: AppSpacing.sm),
            for (final item in lesson.items) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.target,
                              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        IconButton(
                          tooltip: 'Play audio',
                          icon: const Icon(Icons.volume_up_rounded, color: AppColors.blue),
                          onPressed: () async {
                            final ok = await ref
                                .read(ttsProvider)
                                .speak(item.target, locale: language.ttsLocale);
                            if (!ok && context.mounted) {
                              showMessage(context,
                                  'No ${language.name} voice installed. Add one in your phone settings.');
                            }
                          },
                        ),
                      ],
                    ),
                    if (item.reading != null)
                      Text(item.reading!,
                          style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(item.meaningBn,
                        style: text.titleSmall?.copyWith(color: AppColors.purple)),
                    if (item.meaningEn.isNotEmpty) Text(item.meaningEn, style: text.bodySmall),
                    if (item.example.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text('Example: ${item.example}', style: text.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            const SizedBox(height: AppSpacing.md),
            const SectionTitle('Practice'),
            const SizedBox(height: AppSpacing.sm),
            for (final a in Activity.values) ...[
              Builder(builder: (context) {
                final style = _icons[a]!;
                final passed = Progression.passedCount(p, a);
                final complete = passed == Progression.questionsPerActivity;
                final points = Progression.activityPoints(p, a);
                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(style.$1, color: style.$2, size: 28),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.label,
                                    style:
                                        text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                Text(
                                  complete
                                      ? 'Completed  |  ${_fmt(points)} points'
                                      : '$passed/${Progression.questionsPerActivity} passed',
                                  style: text.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: style.$2,
                              minimumSize: const Size(96, 44),
                            ),
                            onPressed: () => context.push(Routes.activity(lessonId, a.name)),
                            child: Text(complete ? 'Review' : (passed == 0 ? 'Start' : 'Continue')),
                          ),
                        ],
                      ),
                      if (a == Activity.speaking && !complete) ...[
                        const SizedBox(height: AppSpacing.sm),
                        TextButton.icon(
                          onPressed: () =>
                              context.push(Routes.activity(lessonId, a.name, camera: true)),
                          icon: const Icon(Icons.face_retouching_natural_rounded),
                          label: const Text('Camera-assisted speaking (optional)'),
                        ),
                      ],
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

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
