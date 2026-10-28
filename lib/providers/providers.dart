import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/utils/json_helpers.dart';
import '../data/backend/firebase_backend.dart';
import '../data/backend/learning_backend.dart';
import '../data/backend/local_backend.dart';
import '../data/catalog/lesson_catalog.dart';
import '../data/models/lesson_progress.dart';
import '../data/models/user_data.dart';
import '../data/repositories/auth_repository.dart';
import '../domain/streak.dart';
import '../features/settings/theme_controller.dart';
import '../services/tts_service.dart';

/// Loaded in main() before the app starts (overridden there).
final catalogProvider = Provider<LessonCatalog>(
  (ref) => throw UnimplementedError('catalogProvider not overridden'),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).userChanges(),
);

final uidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.uid,
);

final backendProvider = Provider<LearningBackend>((ref) {
  switch (AppConfig.backend) {
    case BackendMode.local:
      return LocalBackend(
        prefs: ref.watch(sharedPreferencesProvider),
        catalog: ref.watch(catalogProvider),
      );
    case BackendMode.firebase:
      return FirebaseBackend();
  }
});

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(authRepositoryProvider).watchProfile(uid);
});

final progressMapProvider = StreamProvider<Map<String, LessonProgress>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(backendProvider).watchProgress(uid);
});

final statsProvider = StreamProvider<UserStats>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(backendProvider).watchStats(uid);
});

final dailyProvider = StreamProvider<List<DailyActivity>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(backendProvider).watchDaily(uid);
});

final mistakesProvider = StreamProvider<List<Mistake>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(backendProvider).watchMistakes(uid);
});

final lessonProgressProvider = Provider.family<LessonProgress?, String>(
  (ref, lessonId) => ref.watch(progressMapProvider).valueOrNull?[lessonId],
);

/// Current learning streak in days.
final streakProvider = Provider<int>((ref) {
  final days = ref.watch(dailyProvider).valueOrNull ?? const <DailyActivity>[];
  final active = {for (final d in days) if (d.passed > 0) d.date};
  return StreakCalculator.current(active, DateTime.now());
});

/// Questions passed today.
final todayPassedProvider = Provider<int>((ref) {
  final days = ref.watch(dailyProvider).valueOrNull ?? const <DailyActivity>[];
  final today = dayKey(DateTime.now());
  for (final d in days) {
    if (d.date == today) return d.passed;
  }
  return 0;
});

final ttsProvider = Provider<TtsService>((ref) {
  final tts = TtsService();
  ref.onDispose(tts.stop);
  return tts;
});
