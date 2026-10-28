// Firebase configuration for the Android app (project: aso-bhasha-shiki).
//
// These values come from google-services.json. They are public client
// identifiers, not secrets: access is controlled by Firebase Authentication
// and the Firestore security rules (firestore.rules).
//
// Only Android is configured. For iOS or web, run `flutterfire configure`
// (it regenerates this file with all platforms).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase is only configured for Android. Run flutterfire configure for web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Firebase is only configured for Android. Run flutterfire configure for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA4iF4mz6be7LwAkVdLfgTfSJktKnoEX0E',
    appId: '1:758354935630:android:050e1d462ffc3fe715281f',
    messagingSenderId: '758354935630',
    projectId: 'aso-bhasha-shiki',
    storageBucket: 'aso-bhasha-shiki.firebasestorage.app',
  );
}
