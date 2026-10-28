import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_controller.dart';

/// Device-level settings stored in SharedPreferences.
class AppSettings {
  const AppSettings({
    this.autoPlayAudio = true,
    this.slowByDefault = false,
    this.dailyReminder = false,
  });

  /// Play the reference audio automatically when a question opens.
  final bool autoPlayAudio;

  /// Use slow speech for the first playback.
  final bool slowByDefault;

  /// Preference flag only. Scheduling real reminders is not implemented yet.
  final bool dailyReminder;

  AppSettings copyWith({bool? autoPlayAudio, bool? slowByDefault, bool? dailyReminder}) =>
      AppSettings(
        autoPlayAudio: autoPlayAudio ?? this.autoPlayAudio,
        slowByDefault: slowByDefault ?? this.slowByDefault,
        dailyReminder: dailyReminder ?? this.dailyReminder,
      );
}

class SettingsController extends Notifier<AppSettings> {
  static const _autoPlay = 'set_auto_play';
  static const _slow = 'set_slow';
  static const _reminder = 'set_reminder';

  @override
  AppSettings build() {
    final p = ref.read(sharedPreferencesProvider);
    return AppSettings(
      autoPlayAudio: p.getBool(_autoPlay) ?? true,
      slowByDefault: p.getBool(_slow) ?? false,
      dailyReminder: p.getBool(_reminder) ?? false,
    );
  }

  Future<void> setAutoPlay(bool v) async {
    state = state.copyWith(autoPlayAudio: v);
    await ref.read(sharedPreferencesProvider).setBool(_autoPlay, v);
  }

  Future<void> setSlowByDefault(bool v) async {
    state = state.copyWith(slowByDefault: v);
    await ref.read(sharedPreferencesProvider).setBool(_slow, v);
  }

  Future<void> setDailyReminder(bool v) async {
    state = state.copyWith(dailyReminder: v);
    await ref.read(sharedPreferencesProvider).setBool(_reminder, v);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

/// Whether the onboarding slides were already shown.
class OnboardingController extends Notifier<bool> {
  static const _key = 'onboarding_done';

  @override
  bool build() => ref.read(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> complete() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_key, true);
  }
}

final onboardingDoneProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);
