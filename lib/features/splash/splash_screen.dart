import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Branding shown while Firebase reports the sign-in state.
/// The router redirect moves on automatically, so no timer is needed here.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.translate_rounded, size: 72, color: Colors.white),
              const SizedBox(height: AppSpacing.md),
              Text('Aso Bhasha Shiki',
                  style: text.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: AppSpacing.sm),
              Text('Learn English & Japanese, free',
                  style: text.bodyMedium?.copyWith(color: Colors.white70)),
              const SizedBox(height: AppSpacing.xl),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
