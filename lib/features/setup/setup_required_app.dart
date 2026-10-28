import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shown instead of the app when Firebase has not been configured yet.
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.settings_suggest_rounded, size: 56),
              const SizedBox(height: 16),
              Text('Firebase setup required',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text(
                'Aso Bhasha Shiki uses Firebase for sign-in and progress.\n\n'
                '1. Create a Firebase project and enable Email/Password sign-in.\n'
                '2. Install the FlutterFire CLI:\n'
                '   dart pub global activate flutterfire_cli\n'
                '3. In the project folder run:\n'
                '   flutterfire configure\n'
                '4. Restart the app.\n\n'
                'The README has the full step-by-step guide.',
              ),
              const SizedBox(height: 16),
              Text('Details', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              SelectableText(error, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
