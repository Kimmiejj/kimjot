# Firebase Google Login Setup

The app code is wired for Firebase Auth + Google Sign-In. Finish these Firebase Console steps before running Google login on Android.

## 1. Firebase Android app

Create or open the Firebase project for kimjod, then add an Android app with this package name:

```text
com.kimjot.project
```

## 2. Add SHA fingerprints

Run this from the project root:

```powershell
.\android\gradlew signingReport
```

Copy the debug `SHA1` and `SHA-256` values into:

```text
Firebase Console > Project settings > Your Android app
```

Current debug values from this machine:

```text
SHA1: FA:D2:0E:F3:1F:29:4A:D4:FC:E8:05:85:2F:1A:41:B4:37:C5:9D:C0
SHA-256: 4C:F6:CE:3B:A5:3A:CA:EA:C7:17:E0:9E:35:3F:72:9A:1D:72:9C:30:81:8B:34:5F:FE:B0:15:55:7B:19:D6:55
```

## 3. Enable Google provider

Enable:

```text
Firebase Console > Authentication > Sign-in method > Google
```

This step must create OAuth clients for the project. If Android login fails with
`serverClientId must be provided on Android`, the local `google-services.json`
does not contain OAuth client entries yet.

## 4. Add Firebase config

Use one of these setup paths:

### Recommended: FlutterFire CLI

```powershell
dart pub global activate flutterfire_cli
firebase login
flutterfire configure --platforms=android
```

This should create:

```text
lib/firebase_options.dart
```

The app already imports `firebase_options.dart` and calls:

```dart
Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
```

### Manual Android config

Download `google-services.json` from Firebase Console and place it at:

```text
android/app/google-services.json
```

After enabling Google sign-in and adding SHA values, download
`google-services.json` again. The file should include at least one
`oauth_client` entry. If `oauth_client` is empty, Google Sign-In on Android will
not have the required server client id.

The current Web client ID is stored in `lib/app/app_config.dart`:

```text
193387033943-3gccqmdnssbnutvj3bu1ip4akss6s5ef.apps.googleusercontent.com
```

You can override it without editing code:

```powershell
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

Use the Web client ID from Google Cloud Console or Firebase Authentication's
Google provider configuration.

## Current app code

- Dependencies are installed in `pubspec.yaml`.
- `lib/main.dart` initializes Firebase with `DefaultFirebaseOptions`, watches auth state, signs in with Google, and signs out.
- `android/app/src/main/AndroidManifest.xml` includes the Internet permission.
- `android/app/google-services.json` is present and matches package `com.kimjot.project`.
