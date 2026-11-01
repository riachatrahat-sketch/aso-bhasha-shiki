import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/json_helpers.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/lesson.dart';
import '../../domain/match_game.dart';
import '../../providers/providers.dart';
import 'game_progress.dart';

/// One level of Word Match. Tap a card on the left, then its partner on the right.
class MatchGameScreen extends ConsumerStatefulWidget {
  const MatchGameScreen({
    super.key,
    required this.languageId,
    required this.levelId,
    required this.number,
  });

  final String languageId;
  final String levelId;
  final int number;

  @override
  ConsumerState<MatchGameScreen> createState() => _MatchGameScreenState();
}

class _MatchGameScreenState extends ConsumerState<MatchGameScreen> {
  late final MatchMode _mode;
  late final List<LessonItem> _words;
  late final List<int> _leftOrder; // pair indexes in the order shown on the left
  late final List<int> _rightOrder; // pair indexes in the order shown on the right
  late final int _totalSeconds;

  final Set<int> _matched = {};
  int? _selectedLeft; // position in _leftOrder
  int? _selectedRight; // position in _rightOrder
  int? _wrongLeft;
  int? _wrongRight;
  int _mistakes = 0;
  late int _secondsLeft;
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final catalog = ref.read(catalogProvider);
    final level = math.max(1, math.min(MatchRules.levelCount, widget.number));
    _mode = MatchRules.modeFor(level);
    _words = MatchRules.wordsFor(
      catalog,
      languageId: widget.languageId,
      levelId: widget.levelId,
      level: level,
    );
    _totalSeconds = MatchRules.secondsFor(level);
    _secondsLeft = _totalSeconds;

    int rank(String side, int i) => stableHash('$side#${widget.languageId}#${widget.levelId}#$level#$i');
    _leftOrder = List<int>.generate(_words.length, (i) => i)
      ..sort((a, b) => rank('L', a).compareTo(rank('L', b)));
    _rightOrder = List<int>.generate(_words.length, (i) => i)
      ..sort((a, b) => rank('R', a).compareTo(rank('R', b)));

    if (_words.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick(Timer t) {
    if (_finished) return;
    if (_secondsLeft <= 1) {
      setState(() => _secondsLeft = 0);
      _finish(won: false);
      return;
    }
    setState(() => _secondsLeft--);
  }

  void _speak(String text) {
    final language = ref.read(catalogProvider).language(widget.languageId);
    if (language == null) return;
    ref.read(ttsProvider).speak(text, locale: language.ttsLocale);
  }

  void _tapLeft(int position) {
    if (_finished || _matched.contains(_leftOrder[position])) return;
    if (_mode == MatchMode.sound) _speak(_words[_leftOrder[position]].target);
    setState(() => _selectedLeft = position);
    _checkPair();
  }

  void _tapRight(int position) {
    if (_finished || _matched.contains(_rightOrder[position])) return;
    setState(() => _selectedRight = position);
    _checkPair();
  }

  void _checkPair() {
    final l = _selectedLeft;
    final r = _selectedRight;
    if (l == null || r == null) return;

    final pairLeft = _leftOrder[l];
    final pairRight = _rightOrder[r];
    if (pairLeft == pairRight) {
      _speak(_words[pairLeft].target);
      setState(() {
        _matched.add(pairLeft);
        _selectedLeft = null;
        _selectedRight = null;
      });
      if (_matched.length == _words.length) _finish(won: true);
    } else {
      setState(() {
        _mistakes++;
        _wrongLeft = l;
        _wrongRight = r;
        _selectedLeft = null;
        _selectedRight = null;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _wrongLeft = null;
            _wrongRight = null;
          });
        }
      });
    }
  }

  Future<void> _finish({required bool won}) async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();

    final stars = won ? MatchRules.starsFor(mistakes: _mistakes, pairs: _words.length) : 0;
    if (won) {
      await ref
          .read(gameProgressProvider.notifier)
          .record(widget.languageId, widget.levelId, widget.number, stars);
    }
    if (!mounted) return;
    await _showResult(won: won, stars: stars);
  }

  Future<void> _showResult({required bool won, required int stars}) {
    final text = Theme.of(context).textTheme;
    final hasNext = won && widget.number < MatchRules.levelCount;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(won ? 'Level ${widget.number} complete!' : "Time's up!"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (won)
                Center(
                  child: Text('★' * stars + '☆' * (3 - stars),
                      style: const TextStyle(fontSize: 36, color: Colors.amber)),
                ),
              Text(
                won
                    ? 'Mistakes: $_mistakes. Words you practised:'
                    : 'Try again. These are the words from this level:',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final w in _words)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${w.target}  =  ${w.meaningBn}',
                      style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.pop();
            },
            child: const Text('Levels'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.pushReplacement(
                  Routes.matchGame(widget.languageId, widget.levelId, widget.number));
            },
            child: const Text('Play again'),
          ),
          if (hasNext)
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.pushReplacement(
                    Routes.matchGame(widget.languageId, widget.levelId, widget.number + 1));
              },
              child: const Text('Next level'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (_words.length < 2) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.search_off_rounded, title: 'No words for this level yet'),
      );
    }

    final prompt = switch (_mode) {
      MatchMode.meaning => 'Match each word with its meaning',
      MatchMode.sound => 'Tap a speaker, then tap the word you hear',
      MatchMode.definition => 'Match each word with its English meaning',
    };
    final fraction = math.max(0.0, math.min(1.0, _secondsLeft / _totalSeconds));

    return Scaffold(
      appBar: AppBar(title: Text('Level ${widget.number}')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 20),
              const SizedBox(width: 6),
              Text('$_secondsLeft s', style: text.titleSmall),
              const Spacer(),
              Text('Matched ${_matched.length}/${_words.length}', style: text.titleSmall),
              const Spacer(),
              Text('Mistakes $_mistakes', style: text.titleSmall),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: fraction < 0.25 ? Colors.red : AppColors.blue,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(prompt, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < _leftOrder.length; i++)
                      _MatchTile(
                        label: MatchRules.leftLabel(_mode, _words[_leftOrder[i]]),
                        isSound: _mode == MatchMode.sound,
                        matched: _matched.contains(_leftOrder[i]),
                        selected: _selectedLeft == i,
                        wrong: _wrongLeft == i,
                        onTap: () => _tapLeft(i),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < _rightOrder.length; i++)
                      _MatchTile(
                        label: MatchRules.rightLabel(_mode, _words[_rightOrder[i]]),
                        isSound: false,
                        matched: _matched.contains(_rightOrder[i]),
                        selected: _selectedRight == i,
                        wrong: _wrongRight == i,
                        onTap: () => _tapRight(i),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({
    required this.label,
    required this.isSound,
    required this.matched,
    required this.selected,
    required this.wrong,
    required this.onTap,
  });

  final String? label;
  final bool isSound;
  final bool matched;
  final bool selected;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color border = matched
        ? AppColors.writing
        : (wrong ? Colors.red : (selected ? AppColors.blue : scheme.outlineVariant));
    final Color fill = matched
        ? AppColors.writing.withValues(alpha: 0.15)
        : (wrong
            ? Colors.red.withValues(alpha: 0.12)
            : (selected ? AppColors.blue.withValues(alpha: 0.12) : scheme.surface));

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.button),
          onTap: matched ? null : onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(color: border, width: selected || wrong || matched ? 2 : 1),
            ),
            child: isSound
                ? Icon(matched ? Icons.check_circle_rounded : Icons.volume_up_rounded,
                    size: 32, color: matched ? AppColors.writing : AppColors.listening)
                : Text(
                    label ?? '',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ),
    );
  }
}
