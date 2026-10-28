import '../models/attempt.dart';
import '../models/lesson_progress.dart';
import '../models/user_data.dart';

/// Everything the learning screens need from storage and scoring.
///
/// Two implementations:
///  - FirebaseBackend: reads Firestore, submits answers to a Cloud Function.
///  - LocalBackend:    runs the same rules on the device (demo / no billing).
abstract class LearningBackend {
  Stream<Map<String, LessonProgress>> watchProgress(String uid);
  Stream<UserStats> watchStats(String uid);
  Stream<List<DailyActivity>> watchDaily(String uid);
  Stream<List<Mistake>> watchMistakes(String uid);

  /// Checks the answer, applies scoring and unlocking, stores the result.
  /// Throws AppException with a readable message on failure.
  Future<AttemptResult> submit(String uid, AttemptRequest request);

  /// Removes all learning data of the user (used by "Delete account").
  Future<void> deleteAllData(String uid);
}
