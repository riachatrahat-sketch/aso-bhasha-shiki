import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/audio_buttons.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/lesson.dart';
import '../../services/audio_recorder_service.dart';
import '../../services/face_tracker_service.dart';
import '../../services/speech_service.dart';
import 'activity_shell.dart';
import 'face_assist_panel.dart';

/// Reading & Speaking, with optional camera assist.
///
/// The screen owns the microphone, recorder and camera services so they
/// survive question changes and are always released in [dispose].
class SpeakingScreen extends ConsumerStatefulWidget {
  const SpeakingScreen({super.key, required this.lessonId, this.startWithCamera = false});

  final String lessonId;
  final bool startWithCamera;

  @override
  ConsumerState<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends ConsumerState<SpeakingScreen> {
  final _speech = SpeechService();
  final _recorder = AudioRecorderService();
  final _tracker = FaceTrackerService();

  bool _cameraOn = false;
  bool _cameraStarting = false;

  @override
  void initState() {
    super.initState();
    if (widget.startWithCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _setCamera(true));
    }
  }

  @override
  void dispose() {
    _speech.dispose();
    _recorder.dispose();
    _tracker.dispose();
    super.dispose();
  }

  Future<void> _setCamera(bool on) async {
    if (!on) {
      await _tracker.stop();
      if (mounted) setState(() => _cameraOn = false);
      return;
    }
    setState(() => _cameraStarting = true);
    final result = await _tracker.start();
    if (!mounted) return;
    setState(() {
      _cameraStarting = false;
      _cameraOn = result == FaceStartResult.started;
    });
    switch (result) {
      case FaceStartResult.started:
        break;
      case FaceStartResult.permissionDenied:
        showMessage(context, 'Camera permission was denied. Speaking works without the camera.');
      case FaceStartResult.permissionPermanentlyDenied:
        _askOpenSettings(
          'Camera access is blocked',
          'Allow the camera in your phone settings to use camera assist. '
              'Speaking still works without it.',
        );
      case FaceStartResult.noCamera:
        showMessage(context, 'No camera found on this device.');
      case FaceStartResult.failed:
        showMessage(context, 'Could not start the camera.');
    }
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
        tracker: _tracker,
        cameraOn: _cameraOn,
        cameraStarting: _cameraStarting,
        onCamera: _setCamera,
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
    required this.tracker,
    required this.cameraOn,
    required this.cameraStarting,
    required this.onCamera,
    required this.onOpenSettings,
  });

  final QuestionContext q;
  final SpeechService speech;
  final AudioRecorderService recorder;
  final FaceTrackerService tracker;
  final bool cameraOn;
  final bool cameraStarting;
  final Future<void> Function(bool on) onCamera;
  final Future<void> Function(String title, String body) onOpenSettings;

  @override
  ConsumerState<_SpeakingBody> createState() => _SpeakingBodyState();
}

class _SpeakingBodyState extends ConsumerState<_SpeakingBody> {
  _Phase _phase = _Phase.idle;
  String _partial = '';
  String? _problem;
  FaceActivitySummary? _faceSummary;
  Timer? _maxTimer;
  bool _sawListening = false;

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
      _faceSummary = null;
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

    if (widget.cameraOn) widget.tracker.beginWindow();
    _maxTimer = Timer(const Duration(seconds: 15), _stop);
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

    final summary = widget.cameraOn ? widget.tracker.endWindow() : null;

    if (_azure) {
      final audio = await widget.recorder.stopAsBase64();
      if (!mounted) return;
      setState(() => _faceSummary = summary);
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
      setState(() => _faceSummary = summary);
      await widget.q.submit(transcript: heard);
    }
    if (mounted) setState(() => _phase = _Phase.idle);
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
        AppCard(
          child: Column(
            children: [
              Text('Read this aloud',
                  style: text.labelLarge?.copyWith(color: AppColors.speaking)),
              const SizedBox(height: AppSpacing.sm),
              Text(q.item.target,
                  textAlign: TextAlign.center,
                  style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              if (q.item.reading != null)
                Text(q.item.reading!,
                    style: text.titleMedium?.copyWith(fontStyle: FontStyle.italic)),
              const SizedBox(height: AppSpacing.xs),
              Text(q.item.meaningBn,
                  style: text.titleSmall?.copyWith(color: AppColors.purple)),
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

        // Camera assist (optional)
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text('Camera assist (optional)'),
                subtitle: const Text(
                  'Shows whether your lips and jaw move while you speak. '
                  'It does not change your score. Video is never saved.',
                ),
                value: widget.cameraOn || widget.cameraStarting,
                onChanged: (_phase == _Phase.idle && !widget.cameraStarting)
                    ? (on) => widget.onCamera(on)
                    : null,
              ),
              if (widget.cameraStarting)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: CircularProgressIndicator(),
                ),
              if (widget.cameraOn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: FaceAssistPanel(
                    tracker: widget.tracker,
                    onTurnOff: () => widget.onCamera(false),
                  ),
                ),
            ],
          ),
        ),
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
        if (_faceSummary != null && q.answered) ...[
          const SizedBox(height: AppSpacing.md),
          FaceSummaryCard(summary: _faceSummary!),
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
