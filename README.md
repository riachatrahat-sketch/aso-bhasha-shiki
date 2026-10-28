# Aso Bhasha Shiki

Free English and Japanese learning app (Bengali-speaking learners).
Flutter + Firebase (Auth, Firestore, Cloud Functions).

**Status:** the Dart code has not been compiled or run by the author of this
scaffold (no Flutter SDK was available). Run `flutter pub get`, `flutter analyze`
and `flutter test` first and fix whatever they report.

## Features
- Email/password auth with verification and password reset; Firestore profile.
- 2 languages, levels, lessons (12 sample lessons in `assets/content/lessons.json`).
- 3 activities per lesson, 3 questions each: Speaking, Listening, Writing.
- Scoring: +0.5 per correct question (once), -1 on the first wrong attempt of a
  question, no skipping, questions unlock in order, retry never duplicates points.
- Progress charts, mistakes list, streak, profile, settings, account deletion.
- Optional ML Kit face/mouth-movement assist (never affects the score, video not saved).
- Optional Azure pronunciation assessment through a Cloud Function.

## Architecture
```
lib/
  core/        config, router, theme, utils (normalizer, similarity, validators)
  data/        models, lesson catalog, backends (Firebase / Local), auth repo
  domain/      scoring engine, progression, evaluator, picker, insights
  features/    screens
  services/    TTS, speech-to-text, recorder, face tracker
functions/     Cloud Functions (TypeScript): submitAttempt, deleteAccountData
firestore.rules
```
Scoring lives in `lib/domain` (Dart) and is mirrored in `functions/src` (TS).
In Firebase mode the client cannot write scores: rules deny it and only the
`submitAttempt` function (Admin SDK) does.

## Demo mode without Blaze billing
Auth and the profile still use Firebase (free Spark plan is enough), but scores
and progress can be kept on the device so Cloud Functions are not needed:
```
flutter run --dart-define=BACKEND=local
```
Local mode is not tamper-proof; use `BACKEND=firebase` for server-validated scoring.

## Firebase setup
1. Create a Firebase project; enable Email/Password sign-in.
2. `dart pub global activate flutterfire_cli && flutterfire configure`
   (overwrites the placeholder `lib/firebase_options.dart`).
3. Cloud Functions need the Blaze plan.
4. Deploy and seed:
   ```
   cd functions && npm install && npm run build
   firebase deploy --only firestore:rules,functions
   npm run seed        # needs GOOGLE_APPLICATION_CREDENTIALS or emulator
   ```
5. Run: `flutter run --dart-define=BACKEND=firebase`

### Azure pronunciation (optional)
```
firebase functions:secrets:set AZURE_SPEECH_KEY    # any value, 'unset' disables
```
Set the `AZURE_SPEECH_REGION` param, then run the app with
`--dart-define=PRONUNCIATION_MODE=azure`. Default mode `stt` compares the
speech-to-text transcript with the target and needs no paid service.
Azure support for Japanese assessment is unverified.

## Tests
```
flutter test
cd functions && npm test
```
Dart tests: validators, normalization, scoring, duplicate prevention, unlock
order, lesson completion, streak, speech matching, local backend flow.
The TypeScript logic tests (19) passed when written; the Dart tests were not run.

## Known gaps
- Listening "spoken answer" type not implemented (multiple choice only).
- Reminder notifications: preference flag only.
- Firestore rules and `submitAttempt` not tested on the emulator.
- Package versions in `pubspec.yaml` are unverified.
- Legal screens are templates, not legal advice.

See `docs/PLATFORM_SETUP.md` for Android/iOS permissions.
