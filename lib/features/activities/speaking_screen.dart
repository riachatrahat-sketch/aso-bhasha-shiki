import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/audio_buttons.dart';
import '../../data/models/lesson.dart';
import '../../services/audio_recorder_service.dart';
import '../../services/speech_service.dart';
import 'activity_shell.dart';

/// Speaking practice. Three kinds of question (see [TaskKind]):
/// read a word aloud, say a word from its Bengali meaning, read a sentence aloud.
///
/// The screen owns the microphone and recorder so they survive question
/// changes and are always released in [dispose].
class SpeakingScreen extends ConsumerStatefulWidget {
  const SpeakingScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  ConsumerState<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends ConsumerState<SpeakingScreen> {
  final _speech = SpeechService();
  final _recorder = AudioRecorderService();

  @override
  void dispose() {
    _speech.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _askOpenSettings(String title, String body) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ActivityShell(
      lessonId: widget.lessonId,
      activity: Activity.speaking,
      builder: (context, q) => _SpeakingBody(
        q: q,
        speech: _speech,
        recorder: _recorder,
        onOpenSettings: _askOpenSettings,
      ),
    );
  }
}

enum _Phase { idle, listening, processing }

class _SpeakingBody extends ConsumerStatefulWidget {
  const _SpeakingBody({
    required this.q,
    required this.speech,
    required this.recorder,
    required this.onOpenSettings,
  });

  final QuestionContext q;
  final SpeechService speech;
  final AudioRecorderService recorder;
  final Future<void> Function(String title, String body) onOpenSettings;

  @override
  ConsumerState<_SpeakingBody> createState() => _SpeakingBodyState();
}

class _SpeakingBodyState extends ConsumerState<_SpeakingBody> {
  _Phase _phase = _Phase.idle;
  String _partial = '';
  String? _problem;
  Timer? _maxTimer;
  bool _sawListening = false;

  /// "Need a hint?" was pressed on a translate question.
  bool _hintShown = false;

  bool get _azure => AppConfig.pronunciation == PronunciationMode.azure;

  @override
  void initState() {
    super.initState();
    widget.speech.isListening.addListener(_onListeningChanged);
  }

  @override
  void dispose() {
    widget.speech.isListening.removeListener(_onListeningChanged);
    _maxTimer?.cancel();
    // Release the microphone if the learner leaves mid-recording.
    if (_phase == _Phase.listening) {
      widget.speech.cancel();
      widget.recorder.cancel();
    }
    super.dispose();
  }

  /// The recogniser stops by itself after a pause. Finish the attempt then.
  void _onListeningChanged() {
    final listening = widget.speech.isListening.value;
    if (listening) _sawListening = true;
    if (!_azure && _phase == _Phase.listening && _sawListening && !listening) {
      _stop();
    }
  }

  Future<void> _start() async {
    final q = widget.q;
    setState(() {
      _problem = null;
      _partial = '';
    });

    if (_azure) {
      final ok = await widget.recorder.start();
      if (!ok) {
        _micDenied();
        return;
      }
    } else {
      final availability = await widget.speech.init();
      if (availability == SpeechAvailability.permissionDenied) {
        _micDenied();
        return;
      }
      if (availability == SpeechAvailability.unavailable) {
        setState(() => _problem =
            'Speech recognition is not available on this phone. Install or enable Google '
            '(Android) or Siri dictation (iOS) and try again.');
        return;
      }
      final locale = await widget.speech.resolveLocale(q.language.sttLocale);
      if (locale == null) {
        setState(() => _problem =
            'This phone has no ${q.language.name} speech recognition installed. '
            'Add the language in your voice-input settings.');
        return;
      }
      _sawListening = false;
      await widget.speech.start(
        localeId: locale,
        onPartial: (t) {
          if (mounted) setState(() => _partial = t);
        },
      );
    }

    // Sentences take longer to say than single words.
    final seconds = widget.q.kind == TaskKind.sentenceSpeak ? 25 : 15;
    _maxTimer = Timer(Duration(seconds: seconds), _stop);
    if (mounted) setState(() => _phase = _Phase.listening);
  }

  void _micDenied() {
    setState(() => _problem = 'Microphone access is needed to practise speaking.');
    widget.onOpenSettings(
      'Microphone access is blocked',
      'Allow the microphone (and speech recognition on iPhone) in your phone settings, '
          'then come back.',
    );
  }

  Future<void> _stop() async {
    if (_phase != _Phase.listening) return;
    _maxTimer?.cancel();
    setState(() => _phase = _Phase.processing);

    if (_azure) {
      final audio = await widget.recorder.stopAsBase64();
      if (!mounted) return;
      if (audio == null) {
        setState(() {
          _phase = _Phase.idle;
          _problem = 'Nothing was recorded. Please try again.';
        });
        return;
      }
      await widget.q.submit(audioBase64: audio);
    } else {
      final heard = await widget.speech.stop();
      if (!mounted) return;
      await widget.q.submit(transcript: heard);
    }
    if (mounted) setState(() => _phase = _Phase.idle);
  }

  /// The card that tells the learner what to say.
  Widget _promptCard(BuildContext context) {
    final q = widget.q;
    final item = q.item;
    final text = Theme.of(context).textTheme;
    final emoji = item.emoji;
    final languageName = q.language.name;

    Widget emojiView() => emoji == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(emoji, style: const TextStyle(fontSize: 56)),
          );

    switch (q.kind) {
      case TaskKind.translateSpeak:
        return AppCard(
          child: Column(
            children: [
              Text('Say this in $languageName',
                  style: text.labelLarge?.copyWith(color: AppColors.speaking)),
              const SizedBox(height: AppSpacing.sm),
              emojiView(),
              Text(item.meaningBn,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800, color: AppColors.purple)),
              if (item.meaningEn.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(item.meaningEn,
                      textAlign: TextAlign.center, style: text.bodyMedium),
                ),
              const SizedBox(height: AppSpacing.md),
              if (!_hintShown)
                TextButton.icon(
                  onPressed: q.inputEnabled ? () => setState(() => _hintShown = true) : null,
                  icon: const Icon(Icons.lightbulb_outline_rounded),
                  label: const Text('Need a hint?'),
                )
              else ...[
                Text(item.target,
                    textAlign: TextAlign.center,
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                if (item.reading != null)
                  Text(item.reading!, style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                const SizedBox(height: AppSpacing.sm),
                AudioButtons(text: item.target, locale: q.language.ttsLocale),
              ],
            ],
          ),
        );

      case TaskKind.sentenceSpeak:
        final sentence = item.sentence.isEmpty ? item.target : item.sentence;
        return AppCard(
          child: Column(
            children: [
              Text('Read the sentence aloud',
                  style: text.labelLarge?.copyWith(color: AppColors.speaking)),
              const SizedBox(height: AppSpacing.sm),
              emojiView(),
              Text(sentence,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.xs),
              Text('${item.target}  =  ${item.meaningBn}',
                  textAlign: TextAlign.center,
                  style: text.titleSmall?.copyWith(color: AppColors.purple)),
              const SizedBox(height: AppSpacing.md),
              AudioButtons(text: sentence, locale: q.language.ttsLocale, autoPlay: true),
            ],
          ),
        );

      default:
        return AppCard(
          child: Column(
            children: [
              Text('Read this aloud',
                  style: text.labelLarge?.copyWith(color: AppColors.speaking)),
              const SizedBox(height: AppSpacing.sm),
              emojiView(),
              Text(item.target,
                  textAlign: TextAlign.center,
                  style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              if (item.reading != null)
                Text(item.reading!,
                    style: text.titleMedium?.copyWith(fontStyle: FontStyle.italic)),
              const SizedBox(height: AppSpacing.xs),
              Text(item.meaningBn,
                  style: text.titleSmall?.copyWith(color: AppColors.purple)),
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
    final text = Theme.of(context).textTheme;
    final listening = _phase == _Phase.listening;
    final busy = _phase == _Phase.processing || q.busy;
    final canTap = (q.inputEnabled && _phase == _Phase.idle) || listening;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _promptCard(context),
        const SizedBox(height: AppSpacing.lg),

        // Microphone
        Center(
          child: Column(
            children: [
              Semantics(
                button: true,
                label: listening ? 'Stop recording' : 'Start recording',
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: listening ? Colors.red : AppColors.speaking,
                    ),
                    iconSize: 44,
                    onPressed: canTap ? (listening ? _stop : _start) : null,
                    icon: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                busy
                    ? 'Checking...'
                    : (listening ? 'Listening... tap to stop' : 'Tap the microphone and speak'),
                style: text.bodyMedium,
              ),
            ],
          ),
        ),
        if (listening && _partial.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('"$_partial"',
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(fontStyle: FontStyle.italic)),
        ],
        if (_problem != null) ...[
          const SizedBox(height: AppSpacing.md),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(_problem!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          _azure
              ? 'Scored by Azure Pronunciation Assessment on our server.'
              : 'Scored with speech recognition: it checks that your words were understood. '
                  'It is not a phonetic pronunciation score.',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }
}
