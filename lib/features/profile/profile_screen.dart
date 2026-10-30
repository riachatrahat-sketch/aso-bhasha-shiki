import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_views.dart';
import '../../providers/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Could not load your profile.',
          onRetry: () => ref.invalidate(userProfileProvider),
        ),
        data: (profile) {
          final name = profile?.fullName.isNotEmpty == true
              ? profile!.fullName
              : (user?.displayName ?? 'Learner');
          final email = profile?.email.isNotEmpty == true ? profile!.email : (user?.email ?? '');

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.brandGradient,
                      ),
                      child: Text(
                        profile?.initials ?? '?',
                        style: text.headlineMedium
                            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(name, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    Text(email, style: text.bodyMedium),
                    const SizedBox(height: AppSpacing.sm),
                    if (user?.emailVerified == true)
                      const Chip(
                        avatar: Icon(Icons.verified_rounded, size: 18, color: AppColors.writing),
                        label: Text('Email verified'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  children: [
                    _InfoRow(icon: Icons.wc_rounded, label: 'Gender', value: profile?.gender ?? '-'),
                    const Divider(),
                    _InfoRow(
                      icon: Icons.translate_rounded,
                      label: 'Learning',
                      value: profile?.preferredLanguage == 'ja' ? 'Japanese' : 'English',
                    ),
                    const Divider(),
                    _InfoRow(
                      icon: Icons.flag_rounded,
                      label: 'Daily goal',
                      value: '${profile?.dailyGoal ?? 5} questions',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _NavTile(
                icon: Icons.edit_rounded,
                label: 'Edit profile',
                onTap: () => context.push(Routes.editProfile),
              ),
              _NavTile(
                icon: Icons.settings_rounded,
                label: 'Settings',
                onTap: () => context.push(Routes.settings),
              ),
              _NavTile(
                icon: Icons.history_edu_rounded,
                label: 'Mistakes review',
                onTap: () => context.push(Routes.mistakes),
              ),
              _NavTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => context.push(Routes.legal('privacy')),
              ),
              _NavTile(
                icon: Icons.description_outlined,
                label: 'Terms of Service',
                onTap: () => context.push(Routes.legal('terms')),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, ref),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Your progress is saved to your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok == true) await ref.read(authRepositoryProvider).signOut();
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.purple),
          const SizedBox(width: AppSpacing.md),
          Text(label, style: text.bodyMedium),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.blue),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14),
          ],
        ),
      ),
    );
  }
}
