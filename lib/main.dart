import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/catalog/lesson_catalog.dart';
import 'features/settings/theme_controller.dart';
import 'features/setup/setup_required_app.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only: the face tracker assumes an upright phone.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final catalog = await LessonCatalog.load(rootBundle);

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Firebase is not configured yet (flutterfire configure was not run).
    runApp(SetupRequiredApp(error: e.toString()));
    return;
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        catalogProvider.overrideWithValue(catalog),
      ],
      child: const LingoBridgeApp(),
    ),
  );
}
