import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/json_helpers.dart';
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
      builder: (context, q) => q.kind == TaskKind.unscramble
          ? _UnscrambleBody(q: q)
          : _WritingBody(q: q),
    );
  }
}

/// Typed answers: dictation, translate, fill the blank, whole-sentence dictation.
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

  Widget _promptCard(BuildContext context) {
    final q = widget.q;
    final item = q.item;
    final text = Theme.of(context).textTheme;
    final languageName = q.language.name;
    final sentence = item.sentence.isEmpty ? item.target : item.sentence;

    Widget title(String t) => Text(t,
        style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        textAlign: TextAlign.center);

    Widget emojiView() => item.emoji == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(item.emoji!, style: const TextStyle(fontSize: 56)),
          );

    switch (q.kind) {
      case TaskKind.translateType:
        return AppCard(
          child: Column(
            children: [
              const Icon(Icons.translate_rounded, size: 36, color: AppColors.writing),
              const SizedBox(height: AppSpacing.sm),
              title('Write this in $languageName'),
              const SizedBox(height: AppSpacing.md),
              emojiView(),
              Text(item.meaningBn,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800, color: AppColors.purple)),
              if (item.meaningEn.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(item.meaningEn, textAlign: TextAlign.center, style: text.bodyMedium),
                ),
            ],
          ),
        );

      case TaskKind.cloze:
        return AppCard(
          child: Column(
            children: [
              const Icon(Icons.edit_note_rounded, size: 36, color: AppColors.writing),
              const SizedBox(height: AppSpacing.sm),
              title('Type the missing word'),
              const SizedBox(height: AppSpacing.md),
              Text(item.cloze ?? sentence,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.sm),
              Text('Hint: ${item.meaningBn}',
                  textAlign: TextAlign.center,
                  style: text.titleSmall?.copyWith(color: AppColors.purple)),
            ],
          ),
        );

      case TaskKind.sentenceDictation:
        return AppCard(
          child: Column(
            children: [
              const Icon(Icons.hearing_rounded, size: 36, color: AppColors.writing),
              const SizedBox(height: AppSpacing.sm),
              title('Type the whole sentence you hear'),
              const SizedBox(height: AppSpacing.md),
              AudioButtons(text: sentence, locale: q.language.ttsLocale, autoPlay: true),
            ],
          ),
        );

      default:
        return AppCard(
          child: Column(
            children: [
              const Icon(Icons.edit_rounded, size: 36, color: AppColors.writing),
              const SizedBox(height: AppSpacing.sm),
              title('Type exactly what you hear'),
              const SizedBox(height: AppSpacing.md),
              AudioButtons(text: item.target, locale: q.language.ttsLocale, autoPlay: true),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final isJapanese = q.lesson.language == 'ja';
    final canSubmit = q.inputEnabled && _controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _promptCard(context),
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

/// Build the sentence by tapping the words in the right order (English only).
class _UnscrambleBody extends StatefulWidget {
  const _UnscrambleBody({required this.q});

  final QuestionContext q;

  @override
  State<_UnscrambleBody> createState() => _UnscrambleBodyState();
}

class _UnscrambleBodyState extends State<_UnscrambleBody> {
  late final List<String> _words;
  late final List<int> _shuffled; // indexes into _words, in the order shown
  final List<int> _picked = []; // indexes into _words, in the order the learner tapped

  @override
  void initState() {
    super.initState();
    final item = widget.q.item;
    final sentence = item.sentence.isEmpty ? item.target : item.sentence;
    _words = sentence
        .split(' ')
        .map((w) => w.replaceAll(RegExp(r'[.,!?;:]'), ''))
        .where((w) => w.isNotEmpty)
        .toList();
    final order = List<int>.generate(_words.length, (i) => i)
      ..sort((a, b) => stableHash('${widget.q.lesson.id}#${widget.q.index}#$a${_words[a]}')
          .compareTo(stableHash('${widget.q.lesson.id}#${widget.q.index}#$b${_words[b]}')));
    // Never show the sentence already in order.
    var inOrder = true;
    for (var i = 0; i < order.length; i++) {
      if (order[i] != i) inOrder = false;
    }
    _shuffled = inOrder ? order.reversed.toList() : order;
  }

  String get _answer => _picked.map((i) => _words[i]).join(' ');

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final complete = _picked.length == _words.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            children: [
              const Icon(Icons.sort_rounded, size: 36, color: AppColors.writing),
              const SizedBox(height: AppSpacing.sm),
              Text('Put the words in the right order',
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text('Hint: ${q.item.target} = ${q.item.meaningBn}',
                  textAlign: TextAlign.center,
                  style: text.titleSmall?.copyWith(color: AppColors.purple)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in _picked)
                InputChip(
                  label: Text(_words[i], style: const TextStyle(fontSize: 18)),
                  onDeleted: q.inputEnabled ? () => setState(() => _picked.remove(i)) : null,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final i in _shuffled)
              ActionChip(
                label: Text(_words[i], style: const TextStyle(fontSize: 18)),
                onPressed: (q.inputEnabled && !_picked.contains(i))
                    ? () => setState(() => _picked.add(i))
                    : null,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: (complete && q.inputEnabled) ? () => q.submit(answer: _answer) : null,
          child: const Text('Submit answer'),
        ),
      ],
    );
  }
}
