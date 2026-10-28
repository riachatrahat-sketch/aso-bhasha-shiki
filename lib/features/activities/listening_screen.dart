import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/audio_buttons.dart';
import '../../data/models/lesson.dart';
import '../../data/models/question.dart';
import '../../providers/providers.dart';
import 'activity_shell.dart';

class ListeningScreen extends StatelessWidget {
  const ListeningScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context) {
    return ActivityShell(
      lessonId: lessonId,
      activity: Activity.listening,
      builder: (context, q) => _ListeningBody(q: q),
    );
  }
}

class _ListeningBody extends ConsumerStatefulWidget {
  const _ListeningBody({required this.q});

  final QuestionContext q;

  @override
  ConsumerState<_ListeningBody> createState() => _ListeningBodyState();
}

class _ListeningBodyState extends ConsumerState<_ListeningBody> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final text = Theme.of(context).textTheme;
    final ListeningQuestion question =
        ref.watch(catalogProvider).listeningQuestion(q.lesson, q.index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              const Icon(Icons.headphones_rounded, size: 40, color: AppColors.listening),
              const SizedBox(height: AppSpacing.sm),
              Text(question.prompt,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              AudioButtons(
                text: question.audioText,
                locale: q.language.ttsLocale,
                autoPlay: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final option in question.options) ...[
          _OptionTile(
            label: option,
            selected: _selected == option,
            enabled: q.inputEnabled,
            onTap: () => setState(() => _selected = option),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: (_selected != null && q.inputEnabled)
              ? () => q.submit(answer: _selected)
              : null,
          child: const Text('Check answer'),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.listening.withValues(alpha: 0.12) : scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.button),
          onTap: enabled ? onTap : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(
                color: selected ? AppColors.listening : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.listening : scheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
