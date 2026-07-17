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
the installed app. Configure a permanent release keystore before distributing
the bootstrap updater build; the current Gradle release configuration still
uses the local debug signing key.
