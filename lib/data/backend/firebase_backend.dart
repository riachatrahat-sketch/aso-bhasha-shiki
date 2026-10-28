import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/json_helpers.dart';
import '../models/attempt.dart';
import '../models/lesson_progress.dart';
import '../models/user_data.dart';
import 'learning_backend.dart';

/// Reads progress from Firestore and sends answers to the `submitAttempt`
/// Cloud Function. The function is the only writer of scores, progress,
/// transactions, mistakes and streaks (Firestore rules block client writes).
class FirebaseBackend implements LearningBackend {
  FirebaseBackend({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Stream<Map<String, LessonProgress>> watchProgress(String uid) =>
      _user(uid).collection('lessonProgress').snapshots().map(
            (snap) => {
              for (final d in snap.docs) d.id: LessonProgress.fromMap(d.id, d.data()),
            },
          );

  @override
  Stream<UserStats> watchStats(String uid) =>
      _user(uid).collection('stats').doc('summary').snapshots().map(
            (d) => d.exists ? UserStats.fromMap(d.data()!) : const UserStats.empty(),
          );

  @override
  Stream<List<DailyActivity>> watchDaily(String uid) => _user(uid)
      .collection('dailyStreaks')
      .orderBy('date', descending: true)
      .limit(60)
      .snapshots()
      .map((snap) => [for (final d in snap.docs) DailyActivity.fromMap(d.id, d.data())]);

  @override
  Stream<List<Mistake>> watchMistakes(String uid) => _user(uid)
      .collection('mistakes')
      .orderBy('at', descending: true)
      .limit(30)
      .snapshots()
      .map((snap) => [for (final d in snap.docs) Mistake.fromMap(d.id, d.data())]);

  @override
  Future<AttemptResult> submit(String uid, AttemptRequest request) async {
    try {
      final callable = _functions.httpsCallable(
        'submitAttempt',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      final res = await callable.call<Object?>(request.toMap());
      return AttemptResult.fromMap(Map<String, dynamic>.from(res.data as Map));
    } on FirebaseFunctionsException catch (e) {
      throw AppException(_friendly(e));
    }
  }

  @override
  Future<void> deleteAllData(String uid) async {
    try {
      await _functions.httpsCallable('deleteAccountData').call<Object?>();
    } on FirebaseFunctionsException catch (e) {
      throw AppException(_friendly(e));
    }
  }

  static String _friendly(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Network problem. Check your connection and try again.';
      case 'unauthenticated':
        return 'Please sign in again.';
      case 'not-found':
        return 'The server function is not deployed yet. See the README (Cloud Functions).';
      case 'failed-precondition':
      case 'invalid-argument':
      case 'permission-denied':
      case 'resource-exhausted':
        return e.message ?? 'The request could not be completed.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
