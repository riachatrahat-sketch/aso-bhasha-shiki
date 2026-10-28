# Platform setup (Android / iOS)

Speech, microphone and camera need native permissions. `flutter create .`
generates the `android/` and `ios/` folders; then apply the changes below.

## Android

`android/app/build.gradle(.kts)`: set `minSdk = 23` (ML Kit, record).

`android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.CAMERA"/>

<queries>
  <intent>
    <action android:name="android.speech.RecognitionService"/>
  </intent>
</queries>
```

## iOS

`ios/Podfile`: `platform :ios, '15.5'` (ML Kit requirement).

`ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Used to practise speaking and check your pronunciation.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Used to understand the words you speak.</string>
<key>NSCameraUsageDescription</key>
<string>Optional: shows your mouth movement while you practise speaking. Video is never saved.</string>
```

ML Kit face detection does not run on the iOS simulator on Apple-silicon Macs;
use a real device for the camera assist.

## Things to test on a real device

- Speech recognition locale for Japanese (`ja-JP`) is installed on the phone.
- Camera assist is optional; denying permission must not block speaking.
- Mouth-movement thresholds in `face_tracker_service.dart` are heuristics.

## App name on the phone

The in-app name is "Aso Bhasha Shiki". To change the launcher name:
- Android: `android:label="Aso Bhasha Shiki"` in `AndroidManifest.xml`
- iOS: `CFBundleDisplayName` in `Info.plist`

The Dart package name stays `lingobridge_ai`, so imports are unchanged.
