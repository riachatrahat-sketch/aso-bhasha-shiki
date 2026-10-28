import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

const _hiragana =
    'あいうえお かきくけこ さしすせそ たちつてと なにぬねの はひふへほ まみむめも やゆよ らりるれろ わをん '
    'がぎぐげご ざじずぜぞ だぢづでど ばびぶべぼ ぱぴぷぺぽ ゃゅょっー';

const _katakana =
    'アイウエオ カキクケコ サシスセソ タチツテト ナニヌネノ ハヒフヘホ マミムメモ ヤユヨ ラリルレロ ワヲン '
    'ガギグゲゴ ザジズゼゾ ダヂヅデド バビブベボ パピプペポ ャュョッー';

/// Inserts [s] at the cursor of [c].
void insertAtCursor(TextEditingController c, String s) {
  final sel = c.selection;
  final start = sel.start < 0 ? c.text.length : sel.start;
  final end = sel.end < 0 ? c.text.length : sel.end;
  c.value = TextEditingValue(
    text: c.text.replaceRange(start, end, s),
    selection: TextSelection.collapsed(offset: start + s.length),
  );
}

/// Deletes the character before the cursor (or the selection).
void backspaceAtCursor(TextEditingController c) {
  final sel = c.selection;
  if (c.text.isEmpty) return;
  final end = sel.end < 0 ? c.text.length : sel.end;
  final start = sel.start < 0 ? c.text.length : sel.start;
  if (start != end) {
    c.value = TextEditingValue(
      text: c.text.replaceRange(start, end, ''),
      selection: TextSelection.collapsed(offset: start),
    );
  } else if (start > 0) {
    // Remove one whole character (rune), not one UTF-16 unit.
    final runes = c.text.substring(0, start).runes.toList()..removeLast();
    final newPrefix = String.fromCharCodes(runes);
    c.value = TextEditingValue(
      text: newPrefix + c.text.substring(start),
      selection: TextSelection.collapsed(offset: newPrefix.length),
    );
  }
}

/// On-screen hiragana/katakana palette, for phones without a Japanese keyboard.
Future<void> showKanaKeyboard(BuildContext context, TextEditingController controller) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => DefaultTabController(
      length: 2,
      child: SizedBox(
        height: 380,
        child: Column(
          children: [
            const TabBar(tabs: [Tab(text: 'ひらがな'), Tab(text: 'カタカナ')]),
            Expanded(
              child: TabBarView(
                children: [
                  _KanaGrid(source: _hiragana, controller: controller),
                  _KanaGrid(source: _katakana, controller: controller),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _KanaGrid extends StatelessWidget {
  const _KanaGrid({required this.source, required this.controller});

  final String source;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final chars = source.replaceAll(' ', '').runes.map(String.fromCharCode).toList();
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final ch in chars)
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => insertAtCursor(controller, ch),
                      child: Text(ch, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => backspaceAtCursor(controller),
                  icon: const Icon(Icons.backspace_outlined),
                  label: const Text('Delete'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
