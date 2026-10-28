import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/json_helpers.dart';
import '../../core/widgets/state_views.dart';
import '../../providers/providers.dart';
import 'auth_layout.dart';

/// Shown to signed-in users whose email is not verified yet.
/// Checks every few seconds, so the app continues by itself after the user
/// taps the link in the email.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _poll;
  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    _checking = true;
    try {
      final verified = await ref.read(authRepositoryProvider).reloadAndCheckVerified();
      if (!verified && !silent && mounted) {
        showMessage(context, 'Not verified yet. Open the link in the email first.');
      }
      // When verified, userChanges() emits and the router moves to the dashboard.
    } catch (_) {
      if (!silent && mounted) showMessage(context, 'Could not check. Check your connection.');
    } finally {
      _checking = false;
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(authRepositoryProvider).resendVerification();
      if (!mounted) return;
      showMessage(context, 'Verification email sent.');
      setState(() => _cooldown = 30);
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || _cooldown <= 1) {
          t.cancel();
          if (mounted) setState(() => _cooldown = 0);
        } else {
          setState(() => _cooldown--);
        }
      });
    } on AppException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authStateProvider).valueOrNull?.email ?? '';
    return AuthLayout(
      title: 'Verify your email',
      subtitle: 'We sent a link to $email. Open it, then come back here.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_unread_rounded, size: 64, color: AppColors.blue),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: () => _check(), child: const Text("I've verified my email")),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _cooldown > 0 ? null : _resend,
            child: Text(_cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend email'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Use a different account'),
          ),
        ],
      ),
    );
  }
}
