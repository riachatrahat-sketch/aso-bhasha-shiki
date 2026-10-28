import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Privacy Policy and Terms of Service.
///
/// IMPORTANT: this is a plain-language TEMPLATE written for a portfolio
/// project. If you publish the app, have a qualified person review and adapt
/// it to your situation and local law before release.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  final String doc;

  static const _privacy = <(String, String)>[
    ('What we collect',
        'Your full name, email address, mobile number and gender (that you enter when you sign up), '
            'and your learning data: lesson progress, answers marked wrong, points, daily activity.'),
    ('How we use it',
        'To create your account, save your progress, show your statistics and let you sign in again. '
            'We do not sell your data and we do not show advertising.'),
    ('Your password',
        'Passwords are handled by Firebase Authentication. We never see or store your password.'),
    ('Microphone and speech',
        'The microphone is used only while you practise speaking. By default your speech is turned into text '
            'by your phone\'s speech recognition service. If the optional pronunciation service is enabled, a short '
            'recording is sent to our server and to Microsoft Azure Speech to score it, and is not stored by this app.'),
    ('Camera',
        'The camera is optional and off by default. It runs on your device to find your face and lips for a movement '
            'hint. Video and photos are not saved or uploaded.'),
    ('Where data is stored',
        'Your profile and progress are stored in Google Firebase (Cloud Firestore). '
            'Data is protected by access rules so only you can read your own data.'),
    ('Your choices',
        'You can edit your profile in the app. You can delete your account in Settings, which removes your profile '
            'and learning data.'),
    ('Contact', 'Add your contact email here before publishing.'),
  ];

  static const _terms = <(String, String)>[
    ('Using the app',
        'Aso Bhasha Shiki is a free learning tool. You agree to use it lawfully and not to try to break, '
            'overload or cheat the scoring system.'),
    ('Accounts',
        'You are responsible for keeping your login details private and for the accuracy of the details you give.'),
    ('Learning content',
        'Lessons, translations and pronunciation feedback are provided to help you practise. They may contain mistakes '
            'and are not a substitute for a qualified teacher or an official exam.'),
    ('Scores',
        'Points and streaks are for motivation only and have no cash value.'),
    ('Availability',
        'The app is provided as is. Features may change or be unavailable at times.'),
    ('Changes', 'These terms may be updated. Continued use means you accept the updated terms.'),
  ];

  @override
  Widget build(BuildContext context) {
    final isPrivacy = doc == 'privacy';
    final sections = isPrivacy ? _privacy : _terms;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(isPrivacy ? 'Privacy Policy' : 'Terms of Service')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('Template text for a portfolio project. Review it before publishing the app.'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final s in sections) ...[
            Text(s.$1, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(s.$2, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
