import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/json_helpers.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/attempt.dart';
import '../../data/models/lesson.dart';
import '../../domain/scoring/progression.dart';
import '../../providers/providers.dart';

/// Everything a question body needs.
class QuestionContext {
  const QuestionContext({
    required this.lesson,
    required this.language,
    required this.item,
    required this.index,
    required this.busy,
    required this.answered,
    required this.submit,
  });

  final Lesson lesson;
  final LanguageInfo language;
  final LessonItem item;
  final int index;

  /// An answer is being checked.
  final bool busy;

  /// A result is showing (inputs should be disabled).
  final bool answered;

  final Future<void> Function({String? answer, String? transcript, String? audioBase64}) submit;

  bool get inputEnabled => !busy && !answered;
}

typedef QuestionBuilder = Widget Function(BuildContext context, QuestionContext q);

/// Shared flow for the three activities.
///
/// - Shows the three questions as steps; later steps stay locked.
/// - Sends each answer to the backend (server or local) and shows the result.
/// - A wrong answer shows the correct answer and explanation and offers a retry
///   of the SAME question. "Next" appears only after the question is passed.
class ActivityShell extends ConsumerStatefulWidget {
  const ActivityShell({
    super.key,
    required this.lessonId,
    required this.activity,
    required this.builder,
    this.extraActions = const [],
  });

  final String lessonId;
  final Activity activity;
  final QuestionBuilder builder;
  final List<Widget> extraActions;

  @override
  ConsumerState<ActivityShell> createState() => _ActivityShellState();
}

class _ActivityShellState extends ConsumerState<ActivityShell> {
  /// Question currently shown. Set once from saved progress, then moved by "Next".
  int? _index;
  AttemptResult? _result;
  bool _busy = false;

  /// Bumped on "Try again" so the question body rebuilds with a clean state.
  int _attempt = 0;

  Future<void> _submit({String? answer, String? transcript, String? audioBase64}) async {
    final uid = ref.read(uidProvider);
    if (uid == null || _busy || _result != null || _index == null) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(backendProvider).submit(
            uid,
            AttemptRequest(
              lessonId: widget.lessonId,
              activity: widget.activity,
              index: _index!,
              answer: answer,
              transcript: transcript,
              audioBase64: audioBase64,
            ),
          );
      if (mounted) setState(() => _result = res);
    } on AppException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _retry() => setState(() {
        _result = null;
        _attempt++;
      });

  void _next() => setState(() {
        _index = _index! + 1;
        _result = null;
        _attempt = 0;
      });

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final lesson = catalog.lessonById(widget.lessonId);
    final progressAsync = ref.watch(progressMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.activity.label),
        actions: widget.extraActions,
      ),
      body: lesson == null
          ? const EmptyState(icon: Icons.search_off_rounded, title: 'Lesson not found')
          : progressAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                message: 'Could not load your progress. Check your connection.',
                onRetry: () => ref.invalidate(progressMapProvider),
              ),
              data: (map) {
                final lp = map[widget.lessonId];
                _index ??= Progression.currentIndex(lp, widget.activity);
                if (_index! >= Progression.questionsPerActivity) {
                  return _CompletionView(
                    lessonId: widget.lessonId,
                    activity: widget.activity,
                    points: Progression.activityPoints(lp, widget.activity),
                    lessonDone: Progression.lessonCompleted(lp),
                  );
                }
                return _buildQuestion(context, lesson, lp == null
                    ? 0.0
                    : Progression.activityPoints(lp, widget.activity));
              },
            ),
    );
  }

  Widget _buildQuestion(BuildContext context, Lesson lesson, double activityPoints) {
    final catalog = ref.read(catalogProvider);
    final language = catalog.language(lesson.language)!;
    final index = _index!;
    final result = _result;

    final q = QuestionContext(
      lesson: lesson,
      language: language,
      item: lesson.items[index],
      index: index,
      busy: _busy,
      answered: result != null,
      submit: _submit,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _StepHeader(current: index, points: activityPoints),
        const SizedBox(height: AppSpacing.md),
        KeyedSubtree(
          key: ValueKey('q$index-$_attempt'),
          child: widget.builder(context, q),
        ),
        if (_busy) ...[
          const SizedBox(height: AppSpacing.md),
          const LinearProgressIndicator(),
          const SizedBox(height: 4),
          const Center(child: Text('Checking your answer...')),
        ],
        if (result != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ResultPanel(
            result: result,
            activity: widget.activity,
            isLast: index == Progression.questionsPerActivity - 1,
            onRetry: _retry,
            onNext: _next,
          ),
        ],
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.current, required this.points});

  final int current;
  final double points;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        for (var i = 0; i < Progression.questionsPerActivity; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: i < current
                        ? AppColors.writing
                        : (i == current
                            ? AppColors.blue
                            : AppColors.blue.withValues(alpha: 0.15)),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (i > current) const Icon(Icons.lock_outline_rounded, size: 12),
                    Text(' Q${i + 1}', style: text.labelSmall),
                  ],
                ),
              ],
            ),
          ),
          if (i < Progression.questionsPerActivity - 1) const SizedBox(width: 8),
        ],
        const SizedBox(width: AppSpacing.md),
        Chip(
          avatar: const Icon(Icons.stars_rounded, size: 18, color: AppColors.purple),
          label: Text(_fmt(points)),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.result,
    required this.activity,
    required this.isLast,
    required this.onRetry,
    required this.onNext,
  });

  final AttemptResult result;
  final Activity activity;
  final bool isLast;
  final VoidCallback onRetry;
  final VoidCallback onNext;

  String _delta() {
    if (result.alreadyPassed) return 'Already passed. No extra points.';
    if (result.delta > 0) return '+${_n(result.delta)} points';
    if (result.delta < 0) return '${_n(result.delta)} point${result.delta.abs() == 1 ? '' : 's'}';
    return result.passed ? 'No points change' : 'No more points lost on this question';
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ok = result.passed;
    final color = ok ? AppColors.writing : Theme.of(context).colorScheme.error;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 32),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(ok ? 'Correct!' : 'Not quite',
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color)),
              ),
              Text(_delta(), style: text.titleSmall?.copyWith(color: color)),
            ],
          ),
          if (!ok) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Correct answer', style: text.labelMedium),
            Text(result.correctAnswer,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
          if (result.heard != null && result.heard!.isNotEmpty && activity != Activity.listening) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('You ${activity == Activity.speaking ? 'said' : 'typed'}', style: text.labelMedium),
            Text(result.heard!, style: text.bodyLarge),
          ],
          if (result.explanation.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(result.explanation, style: text.bodyMedium),
          ],
          if (activity == Activity.speaking) _SpeechScores(result: result),
          const SizedBox(height: AppSpacing.md),
          if (ok)
            FilledButton(
              onPressed: onNext,
              child: Text(isLast ? 'Finish activity' : 'Next question'),
            )
          else
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
        ],
      ),
    );
  }
}

class _SpeechScores extends StatelessWidget {
  const _SpeechScores({required this.result});

  final AttemptResult result;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, double)>[
      if (result.pronScore != null) ('Pronunciation', result.pronScore! / 100),
      if (result.fluencyScore != null) ('Fluency', result.fluencyScore! / 100),
      if (result.accuracy != null && result.pronScore == null) ('Word accuracy', result.accuracy!),
      if (result.completeness != null) ('Completeness', result.completeness!),
      if (result.similarity != null && result.pronScore == null) ('Match', result.similarity!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(width: 110, child: Text(r.$1, style: text.bodySmall)),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: r.$2.clamp(0.0, 1.0),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${(r.$2.clamp(0.0, 1.0) * 100).round()}%', style: text.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.lessonId,
    required this.activity,
    required this.points,
    required this.lessonDone,
  });

  final String lessonId;
  final Activity activity;
  final double points;
  final bool lessonDone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pts = points == points.roundToDouble() ? points.toInt().toString() : points.toStringAsFixed(1);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded, size: 72, color: AppColors.purple),
            const SizedBox(height: AppSpacing.md),
            Text('${activity.shortLabel} complete!',
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            Text('You earned $pts points in this activity.', style: text.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            if (lessonDone)
              FilledButton(
                onPressed: () => context.pushReplacement(Routes.result(lessonId)),
                child: const Text('See lesson summary'),
              ),
            if (lessonDone) const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Back to lesson'),
            ),
          ],
        ),
      ),
    );
  }
}
