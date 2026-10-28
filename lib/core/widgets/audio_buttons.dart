import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_controller.dart';
import '../../providers/providers.dart';
import 'state_views.dart';

/// Play / slow-play buttons for reference audio (text-to-speech).
class AudioButtons extends ConsumerStatefulWidget {
  const AudioButtons({
    super.key,
    required this.text,
    required this.locale,
    this.autoPlay = false,
  });

  final String text;

  /// TTS locale, e.g. en-US or ja-JP.
  final String locale;

  /// Play once when the widget appears (if the user enabled auto-play).
  final bool autoPlay;

  @override
  ConsumerState<AudioButtons> createState() => _AudioButtonsState();
}

class _AudioButtonsState extends ConsumerState<AudioButtons> {
  @override
  void initState() {
    super.initState();
    if (widget.autoPlay && ref.read(settingsProvider).autoPlayAudio) {
      final slow = ref.read(settingsProvider).slowByDefault;
      // Wait one frame so the screen is visible before speaking.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play(slow: slow, silent: true);
      });
    }
  }

  Future<void> _play({required bool slow, bool silent = false}) async {
    final ok = await ref
        .read(ttsProvider)
        .speak(widget.text, locale: widget.locale, slow: slow);
    if (!ok && !silent && mounted) {
      showMessage(
        context,
        'No voice found for this language. Install it in your phone settings '
        '(Text-to-speech output), then try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
          onPressed: () => _play(slow: false),
          icon: const Icon(Icons.volume_up_rounded),
          label: const Text('Play'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(140, 48)),
          onPressed: () => _play(slow: true),
          icon: const Icon(Icons.slow_motion_video_rounded),
          label: const Text('Slow'),
        ),
      ],
    );
  }
}
