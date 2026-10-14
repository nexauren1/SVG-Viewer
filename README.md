# SVG Viewer

A privacy-first Android SVG viewer with folder scanning and a source editor, built with Flutter and Dart.

## Features

- Open individual SVG files using Android's system file picker.
- Select a folder through Android's Storage Access Framework and recursively find SVG files in that folder and accessible subfolders.
- Keep a persisted folder grant so the user can rescan without choosing the folder every time.
- Preview SVGs with pinch zoom and pan.
- Switch preview background colors.
- Edit SVG source text and save an edited copy through Android's document picker, preserving the original by default.
- Share SVG source text to compatible Android apps.
- Work offline; no account or upload server is required.

## Storage and privacy

The app does not request broad all-files access. The user chooses the folder to scan in Android's system picker, and the app only scans that folder tree within the access granted by the document provider. Android or a provider may hide protected folders or files.

## Build on GitHub

The workflow at `.github/workflows/android-release.yml` creates the Android host project on a GitHub-hosted runner, overlays the Flutter source and Android Storage Access Framework implementation, runs `flutter analyze` and `flutter test`, and builds both an APK and an Android App Bundle.

- Pushes to `main` build and update the **nightly** pre-release.
- Pushing a version tag such as `v1.0.0` builds and publishes a versioned GitHub Release.
- APK and AAB are also uploaded as workflow artifacts.

The automatically generated release build is suitable for device testing. It uses the generated Flutter Android project's default debug signing configuration unless a production signing key is configured. Before Google Play production publishing, configure a private upload keystore using GitHub Actions secrets and the official Flutter Android signing instructions.

## Development

The repository keeps the Dart app source in `lib/`, tests in `test/`, and the custom Android host activity in `android/app/src/main/kotlin/com/nexauren/svgviewer/MainActivity.kt`. The CI workflow generates the rest of the Android host scaffold using the current stable Flutter SDK.
