import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/json_helpers.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../providers/providers.dart';
import 'settings_controller.dart';
import 'theme_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final uid = ref.watch(uidProvider);
    final settings = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final text = Theme.of(context).textTheme;

    Future<void> saveProfileSetting({String? language, int? goal}) async {
      if (uid == null) return;
      try {
        await ref
            .read(authRepositoryProvider)
            .updateSettings(uid, preferredLanguage: language, dailyGoal: goal);
      } on AppException catch (e) {
        if (context.mounted) showMessage(context, e.message);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SectionTitle('Learning'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preferred language', style: text.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('English')),
                    ButtonSegment(value: 'ja', label: Text('Japanese')),
                  ],
                  selected: {profile?.preferredLanguage ?? 'en'},
                  onSelectionChanged: (s) => saveProfileSetting(language: s.first),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Daily goal (questions to pass per day)', style: text.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 3, label: Text('3')),
                    ButtonSegment(value: 5, label: Text('5')),
                    ButtonSegment(value: 10, label: Text('10')),
                    ButtonSegment(value: 15, label: Text('15')),
                  ],
                  selected: {
                    const [3, 5, 10, 15].contains(profile?.dailyGoal) ? profile!.dailyGoal : 5,
                  },
                  onSelectionChanged: (s) => saveProfileSetting(goal: s.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          const SectionTitle('Sound'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Play audio automatically'),
                  subtitle: const Text('When a question opens'),
                  value: settings.autoPlayAudio,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setAutoPlay(v),
                ),
                SwitchListTile(
                  title: const Text('Slow speech first'),
                  subtitle: const Text('Automatic playback uses the slow voice'),
                  value: settings.slowByDefault,
                  onChanged: (v) => ref.read(settingsProvider.notifier).setSlowByDefault(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          const SectionTitle('Notifications'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text('Daily reminder'),
              subtitle: const Text('Preference is saved. Reminders are not sent yet.'),
              value: settings.dailyReminder,
              onChanged: (v) => ref.read(settingsProvider.notifier).setDailyReminder(v),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          const SectionTitle('Appearance'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).setMode(s.first),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          const SectionTitle('Permissions'),
          const SizedBox(height: AppSpacing.sm),
          const AppCard(child: _CameraPermissionRow()),
          const SizedBox(height: AppSpacing.lg),

          const SectionTitle('Legal'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  onTap: () => context.push(Routes.legal('privacy')),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  onTap: () => context.push(Routes.legal('terms')),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          const SectionTitle('Account'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Log out'),
                  onTap: () => ref.read(authRepositoryProvider).signOut(),
                ),
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded,
                      color: Theme.of(context).colorScheme.error),
                  title: Text('Delete account',
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  onTap: () => _deleteAccount(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your account, profile, points and progress. '
              'It cannot be undone.\n\nEnter your password to confirm.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    final typed = password.text;
    password.dispose();
    if (confirmed != true || !context.mounted) return;
    if (typed.isEmpty) {
      showMessage(context, 'Enter your password to delete your account.');
      return;
    }

    final auth = ref.read(authRepositoryProvider);
    final uid = ref.read(uidProvider);
    if (uid == null) return;
    try {
      // 1. Confirm the password first, so nothing is deleted on a wrong password.
      await auth.reauthenticate(password: typed);
      // 2. Delete progress and scores.
      await ref.read(backendProvider).deleteAllData(uid);
      // 3. Delete the profile document (name, email, gender). This must happen
      //    while still signed in, so it comes before the account is removed.
      await auth.deleteProfile(uid);
      // 4. Delete the sign-in account. The router then returns to the login screen.
      await auth.finishDeleteAuthUser();
    } on AppException catch (e) {
      if (context.mounted) showMessage(context, e.message);
    }
  }
}

class _CameraPermissionRow extends StatefulWidget {
  const _CameraPermissionRow();

  @override
  State<_CameraPermissionRow> createState() => _CameraPermissionRowState();
}

class _CameraPermissionRowState extends State<_CameraPermissionRow> with WidgetsBindingObserver {
  PermissionStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-read the status when the user comes back from the system settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await Permission.camera.status;
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    final granted = _status?.isGranted == true;
    return Row(
      children: [
        Icon(granted ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            color: granted ? AppColors.writing : AppColors.purple),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Camera', style: Theme.of(context).textTheme.titleSmall),
              Text(
                _status == null
                    ? 'Checking...'
                    : (granted ? 'Allowed (used only for camera assist)' : 'Not allowed'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        TextButton(onPressed: openAppSettings, child: const Text('Manage')),
      ],
    );
  }
}
