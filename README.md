# kimjod

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Required Android updates

The app checks the public Firestore document `app_config/android` before login.
Create it with these fields:

- `minimumVersionCode` (number): versions below this value are blocked.
- `latestVersionName` (string): version shown on the update screen.
- `updateUrl` (string): direct HTTPS URL to the signed APK file (not a web page).
- `messageTh` and `messageEn` (optional strings): release-specific messages.

For each release, increase the build number after `+` in `pubspec.yaml`, build
and publish the signed release first, and only then raise
`minimumVersionCode`. Deploy `firestore.rules` before enabling this document.
When an update is required, Android DownloadManager downloads the APK with a
system notification. The app then opens the Android package installer. On the
first update, the user must allow Kimjod to install unknown apps and must confirm
the installation. Android only permits fully silent installation for managed
device-owner/profile-owner deployments.

Every APK update must keep the same `applicationId` and signing certificate as
the installed app. This workspace's ignored `android/key.properties` points to
the existing signing key at `C:/Users/ChisanuchaK/.android/debug.keystore` so
updates remain compatible with currently installed builds. Back up that
keystore securely outside the source repository; losing it means future APKs
cannot be installed over users' existing app.

## Local Release Center

The local dashboard builds and publishes an Android release, updates the
Firestore minimum version, and reports Firebase Auth plus privacy-safe app usage
telemetry.

Prerequisites:

- Flutter and Firebase CLI installed.
- Git signed in through Git Credential Manager with write access to
  `Kimmiejj/kimjot` (or set `KIMJOD_GITHUB_TOKEN`).
- `firebase login` completed with access to the `kimjot` project.
- The Android signing certificate must match the certificate used by installed
  copies of the app.

Run it from the project root:

```powershell
node release-center/server.js
```

Then open `http://127.0.0.1:4173`. **Build APK** updates `pubspec.yaml` and stages
the versioned release without affecting users. **Send update** deploys Firestore
rules, uploads the APK to GitHub Releases, records the release, and only then raises
`app_config/android.minimumVersionCode`. The staged build survives a Release
Center restart. If build or Hosting deploy fails, the required-version document
is not changed and the staged APK can be retried.

The release-history **Send** button is a forward-only rollback. It rebuilds the
selected Git-tagged source with a version code higher than every prior build,
switches the required update to that APK, and deletes releases newer than the
selected target. Android can therefore install the selected app version without
uninstalling the app or clearing user data.

Dashboard metrics include registered users, active users, sessions, recent
online presence, feature usage, installed versions, and release history. The app
does not send transaction amounts or encrypted transaction payloads as usage
telemetry.

On Windows, double-click `เปิด Kimjod Release Center.cmd` in the project folder
to start the local server and open the dashboard without entering a command.
