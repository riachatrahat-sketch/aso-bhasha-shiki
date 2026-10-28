import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/audio_buttons.dart';
import '../../data/models/lesson.dart';
import 'activity_shell.dart';
import 'kana_keyboard.dart';

class WritingScreen extends StatelessWidget {
  const WritingScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context) {
    return ActivityShell(
      lessonId: lessonId,
      activity: Activity.writing,
      builder: (context, q) => _WritingBody(q: q),
    );
  }
}

class _WritingBody extends StatefulWidget {
  const _WritingBody({required this.q});

  final QuestionContext q;

  @override
  State<_WritingBody> createState() => _WritingBodyState();
}

class _WritingBodyState extends State<_WritingBody> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final text = Theme.of(context).textTheme;
    final isJapanese = q.lesson.language == 'ja';
    final canSubmit = q.inputEnabled && _controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              const Icon(Icons.edit_rounded, size: 40, color: AppColors.writing),
              const SizedBox(height: AppSpacing.sm),
              Text('Type exactly what you hear',
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              AudioButtons(
                text: q.item.target,
                locale: q.language.ttsLocale,
                autoPlay: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _controller,
          enabled: q.inputEnabled,
          // Autocorrect would silently fix spelling mistakes, which defeats the exercise.
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          style: const TextStyle(fontSize: 20),
          decoration: InputDecoration(
            labelText: isJapanese ? 'Type in Japanese' : 'Type in English',
            helperText: isJapanese
                ? 'Switch your phone keyboard to Japanese, or use the kana keyboard.'
                : null,
            helperMaxLines: 2,
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: q.inputEnabled ? _controller.clear : null,
                  ),
          ),
          onSubmitted: (_) {
            if (canSubmit) q.submit(answer: _controller.text);
          },
        ),
        if (isJapanese) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: q.inputEnabled ? () => showKanaKeyboard(context, _controller) : null,
              icon: const Icon(Icons.keyboard_alt_outlined),
              label: const Text('Kana keyboard'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: canSubmit ? () => q.submit(answer: _controller.text) : null,
          child: const Text('Submit answer'),
        ),
      ],
    );
  }
}
