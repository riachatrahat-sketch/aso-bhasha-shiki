import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../services/face_tracker_service.dart';

/// Live camera preview with face status and a lip-gap meter.
///
/// Supplementary only: it shows that a face is found and the lips move. It
/// does not judge pronunciation.
class FaceAssistPanel extends StatelessWidget {
  const FaceAssistPanel({super.key, required this.tracker, required this.onTurnOff});

  final FaceTrackerService tracker;
  final VoidCallback onTurnOff;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tracker,
      builder: (context, _) {
        final controller = tracker.camera;
        if (controller == null || !controller.value.isInitialized) {
          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        }
        final text = Theme.of(context).textTheme;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize?.height ?? 240,
                    height: controller.value.previewSize?.width ?? 320,
                    child: CameraPreview(controller),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (tracker.faceDetected ? AppColors.writing : Colors.orange)
                          .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tracker.faceDetected ? 'Face found' : 'Show your face',
                      style: text.labelMedium?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton.filledTonal(
                    tooltip: 'Turn camera off',
                    onPressed: onTurnOff,
                    icon: const Icon(Icons.videocam_off_rounded),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mouth movement',
                          style: text.labelSmall?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        // A lip gap of about 15% of the face height is a wide-open mouth.
                        value: (tracker.mouthOpenness / 0.15).clamp(0.0, 1.0),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: Colors.white24,
                        color: AppColors.purple,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Result of the camera hint after one attempt.
class FaceSummaryCard extends StatelessWidget {
  const FaceSummaryCard({super.key, required this.summary});

  final FaceActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final String message;
    final IconData icon;
    if (summary.facePresentRatio < 0.5) {
      message = 'Your face was hard to see, so there is no movement hint this time.';
      icon = Icons.face_retouching_off_rounded;
    } else if (summary.movementDetected) {
      message = 'We saw your lips and jaw move while you spoke.';
      icon = Icons.check_circle_outline_rounded;
    } else {
      message = 'We saw very little lip movement. Try opening your mouth a little more.';
      icon = Icons.info_outline_rounded;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.purple),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Camera hint', style: text.titleSmall),
                  Text(message, style: text.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    'This is a movement hint only. It cannot tell if your pronunciation '
                    'was correct and it does not change your points.',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
