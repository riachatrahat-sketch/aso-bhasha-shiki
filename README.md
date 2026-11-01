# Esho Bhasha Shikhi

Free English and Japanese learning app (Bengali-speaking learners).
Flutter + Firebase (Auth, Firestore, Cloud Functions).

**Status:** analysed and tested by GitHub Actions (`.github/workflows/ci.yml`).

## Features
- Email/password auth with verification and password reset; Firestore profile.
- 2 languages and 439 lessons = 3,951 tasks in `assets/content/lessons.json`.
  - English: Kids Starter, Beginner, Elementary, Intermediate, Advanced, IELTS Vocabulary.
  - Japanese: Kids Starter, Hiragana, Katakana, JLPT N5, JLPT N4, MEXT Scholarship Vocabulary.
  - Kids levels use big emoji pictures and very simple words; the level screen groups levels
    into "Kids" and "Teens and adults".
  Lessons are written in simple text files under `tools/content/` and built into the JSON
  with `python3 tools/build_lessons.py`, which also checks the content for mistakes.
  Content is AI-written; a native Bengali/Japanese speaker should review it.
- 3 activities per lesson, 3 questions each, and the questions are **not all the same**:
  - Speaking: read a word aloud, say a word from its Bengali meaning, read a whole sentence.
  - Listening: hear a word and pick its meaning or spelling; hear a sentence and pick the
    missing or used word.
  - Writing: dictation, translate Bengali to the word, fill the blank in a sentence,
    put the words of a sentence in order, type a whole sentence you hear.
  - Speaking, Listening and Writing start on different words, so one sentence is not repeated.
- Lessons get harder as you go: every lesson has a `tier` (1-5) that rises inside a level and
  from level to level. Early tiers use easy "copy what you hear" questions; later tiers use
  translation, sentences, fill-in-the-blank and word order, and 5 listening options.
  The build script writes the plan to each lesson's `tasks` field; the app and the Cloud
  Function only read it.
- Word Match game (Home > Play and learn): 30 levels per word set (English or Japanese,
  Kids / general / IELTS / MEXT). Match words with meanings, sounds or English definitions
  against the clock; more pairs and less time on every level; stars saved on the device.
- Scoring: +0.5 per correct question (once), -1 on the first wrong attempt of a
  question, no skipping, questions unlock in order, retry never duplicates points.
- Progress charts, mistakes list, streak, profile, settings, account deletion.
- Optional Azure pronunciation assessment through a Cloud Function.

## Architecture
```
lib/
  core/        config, router, theme, utils (normalizer, similarity, validators)
  data/        models, lesson catalog, backends (Firebase / Local), auth repo
  domain/      scoring engine, progression, evaluator, picker, insights
  features/    screens
  services/    TTS, speech-to-text, recorder
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
The Dart tests run in GitHub Actions on every push (see below).

## Known gaps
- Listening is multiple choice only.
- Reminder notifications: preference flag only.
- Firestore rules and `submitAttempt` not tested on the emulator.
- Package versions in `pubspec.yaml` are unverified.
- Legal screens are templates, not legal advice.

See `docs/PLATFORM_SETUP.md` for Android/iOS permissions.

## No local Flutter? Use GitHub Actions
`.github/workflows/ci.yml` runs `flutter analyze`, `flutter test`, builds a debug
APK (downloadable under the run's Artifacts) and builds/tests the Cloud Functions.
Open the repository's **Actions** tab after each push.
