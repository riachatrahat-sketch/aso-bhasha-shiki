import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/activities/lesson_result_screen.dart';
import '../../features/activities/listening_screen.dart';
import '../../features/activities/speaking_screen.dart';
import '../../features/activities/writing_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/verify_email_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/learn/language_selection_screen.dart';
import '../../features/learn/lesson_detail_screen.dart';
import '../../features/learn/lesson_list_screen.dart';
import '../../features/learn/level_selection_screen.dart';
import '../../features/legal/legal_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/progress/mistakes_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/settings/settings_controller.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../providers/providers.dart';

abstract final class Routes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const forgot = '/forgot';
  static const verify = '/verify';
  static const home = '/home';
  static const learn = '/learn';
  static const progress = '/progress';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const settings = '/settings';
  static const mistakes = '/mistakes';

  static String levels(String lang) => '/learn/$lang';
  static String lessons(String lang, String level) => '/learn/$lang/$level';
  static String lesson(String id) => '/lesson/$id';
  static String activity(String id, String name, {bool camera = false}) =>
      '/lesson/$id/$name${camera ? '?camera=1' : ''}';
  static String result(String id) => '/lesson/$id/result';
  static String legal(String doc) => '/legal/$doc';
}

const _signedOutRoutes = {Routes.onboarding, Routes.login, Routes.signup, Routes.forgot};

final routerProvider = Provider<GoRouter>((ref) {
  // Re-evaluate redirects whenever auth or onboarding state changes.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authStateProvider, (_, __) => refresh.value++);
  ref.listen(onboardingDoneProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;

      // Terms and privacy pages are readable by everyone.
      if (loc.startsWith('/legal/')) return null;

      // Wait on the splash screen until Firebase reports the auth state.
      if (auth.isLoading) return loc == Routes.splash ? null : Routes.splash;

      final user = auth.valueOrNull;
      if (user == null) {
        final onboarded = ref.read(onboardingDoneProvider);
        if (!onboarded) return loc == Routes.onboarding ? null : Routes.onboarding;
        return _signedOutRoutes.contains(loc) && loc != Routes.onboarding ? null : Routes.login;
      }

      if (!user.emailVerified) return loc == Routes.verify ? null : Routes.verify;

      if (loc == Routes.splash || loc == Routes.verify || _signedOutRoutes.contains(loc)) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (c, s) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: Routes.login, builder: (c, s) => const LoginScreen()),
      GoRoute(path: Routes.signup, builder: (c, s) => const SignupScreen()),
      GoRoute(path: Routes.forgot, builder: (c, s) => const ForgotPasswordScreen()),
      GoRoute(path: Routes.verify, builder: (c, s) => const VerifyEmailScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (c, s) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.learn, builder: (c, s) => const LanguageSelectionScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.progress, builder: (c, s) => const ProgressScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.profile, builder: (c, s) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/learn/:lang',
        builder: (c, s) => LevelSelectionScreen(languageId: s.pathParameters['lang']!),
      ),
      GoRoute(
        path: '/learn/:lang/:level',
        builder: (c, s) => LessonListScreen(
          languageId: s.pathParameters['lang']!,
          levelId: s.pathParameters['level']!,
        ),
      ),
      GoRoute(
        path: '/lesson/:id',
        builder: (c, s) => LessonDetailScreen(lessonId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/lesson/:id/speaking',
        builder: (c, s) => SpeakingScreen(
          lessonId: s.pathParameters['id']!,
          startWithCamera: s.uri.queryParameters['camera'] == '1',
        ),
      ),
      GoRoute(
        path: '/lesson/:id/listening',
        builder: (c, s) => ListeningScreen(lessonId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/lesson/:id/writing',
        builder: (c, s) => WritingScreen(lessonId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/lesson/:id/result',
        builder: (c, s) => LessonResultScreen(lessonId: s.pathParameters['id']!),
      ),
      GoRoute(path: Routes.mistakes, builder: (c, s) => const MistakesScreen()),
      GoRoute(path: Routes.editProfile, builder: (c, s) => const EditProfileScreen()),
      GoRoute(path: Routes.settings, builder: (c, s) => const SettingsScreen()),
      GoRoute(
        path: '/legal/:doc',
        builder: (c, s) => LegalScreen(doc: s.pathParameters['doc']!),
      ),
    ],
  );
});
