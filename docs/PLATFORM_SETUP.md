# Platform setup (Android / iOS)

Speech and microphone need native permissions. `flutter create .`
generates the `android/` and `ios/` folders; then apply the changes below.

## Android

`android/app/build.gradle(.kts)`: set `minSdk = 23` (record, speech).

`android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>

<queries>
  <intent>
    <action android:name="android.speech.RecognitionService"/>
  </intent>
</queries>
```

## iOS

`ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Used to practise speaking and check your pronunciation.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Used to understand the words you speak.</string>
```

## Things to test on a real device

- Speech recognition locale for Japanese (`ja-JP`) is installed on the phone.
- Sentence speaking (longer phrases) is recognised correctly by the phone's speech service.

## App name on the phone

The in-app name is "Esho Bhasha Shikhi". To change the launcher name:
- Android: `android:label="Esho Bhasha Shikhi"` in `AndroidManifest.xml`
- iOS: `CFBundleDisplayName` in `Info.plist`

The Dart package name stays `lingobridge_ai`, so imports are unchanged.
