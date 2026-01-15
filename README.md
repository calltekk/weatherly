# Weatherly

A cross-platform Flutter application scaffolded from the standard Flutter template. This README documents setup, development, testing, building, and troubleshooting steps for Windows, macOS, Linux, Android, iOS and web targets.

## Project Overview

- **Name:** Weatherly (code name `flutter_application_1`)
- **Purpose:** Example Flutter app demonstrating multi-platform support and typical project structure.
- **Entry point:** `lib/main.dart`

## Table of Contents

- **Prerequisites**
- **Initial setup**
- **Run (development)**
- **Run (specific platforms)**
- **Build (release)**
- **Testing**
- **Project structure**
- **Common tasks & commands**
- **Troubleshooting**
- **Contributing**
- **License**

## Prerequisites

- Install Flutter SDK (stable channel recommended): https://flutter.dev/docs/get-started/install
- Add `flutter` to your `PATH` and run `flutter doctor` to ensure required dependencies are present.
- Platform-specific requirements:
  - Android: Android Studio or command-line SDK, Android SDK platform tools, an Android device or emulator.
  - iOS (macOS only): Xcode and command line tools; a valid signing identity for device builds.
  - Windows: Visual Studio with Desktop development workload.
  - Linux: Development packages for building Linux desktop apps (varies by distro).

## Initial setup

1. From the project root (`flutter_application_1/`) get dependencies:

```powershell
flutter pub get
```

2. Verify environment and dependencies:

```powershell
flutter doctor -v
flutter analyze
```

## Run (development)

Run on the default connected device or emulator:

```powershell
flutter run
```

Select an available device with `flutter devices` or launch a specific target:

```powershell
flutter run -d windows    # Windows desktop
flutter run -d linux      # Linux desktop
flutter run -d macos      # macOS desktop
flutter run -d chrome     # Web (Chrome)
flutter run -d android    # Android device/emulator
```

## Run (specific platforms / Tips)

- Android: Launch an emulator from Android Studio or use `flutter emulators --launch <id>`.
- iOS: Open Xcode workspace at `ios/Runner.xcworkspace` to manage signing and provisioning before running on a physical device.
- Web: Use `flutter run -d chrome` or `flutter build web` for production assets.

## Build (release)

- Android (APK):

```powershell
flutter build apk --release
```

- Android (App bundle):

```powershell
flutter build appbundle --release
```

- iOS (macOS host):

```bash
flutter build ios --release
# then use Xcode for archive/signing and publishing
```

- Web:

```powershell
flutter build web --release
```

- Desktop (example Windows):

```powershell
flutter build windows --release
```

## Testing

- Run unit & widget tests:

```powershell
flutter test
```

- The existing widget test lives at `test/widget_test.dart` and exercises the basic app widget tree.

## Project structure (high-level)

- `lib/` — Application code and entrypoint (`lib/main.dart`).
- `test/` — Tests (unit and widget tests). See `test/widget_test.dart`.
- `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/` — Platform-specific projects and build artifacts.
- `pubspec.yaml` — Dart/Flutter dependencies, assets, and metadata.

## Common tasks & commands

- Format code:

```powershell
flutter format .
```

- Analyze code (static analysis):

```powershell
flutter analyze
```

- Upgrade dependencies:

```powershell
flutter pub upgrade
```

## Troubleshooting

- `flutter doctor` shows missing dependencies — follow the suggestions it prints.
- Android build failures: ensure `local.properties` contains the correct `sdk.dir` path and you have matching Android SDK components installed.
- iOS code signing errors: open `ios/Runner.xcworkspace` in Xcode and set a valid Team and provisioning profile.
- Desktop build errors on Windows: install Visual Studio with the “Desktop development with C++” workload.

If a package fails to compile after SDK upgrades, run:

```powershell
flutter clean
flutter pub get
```

## Continuous integration (example)

- A minimal GitHub Actions workflow would run `flutter pub get`, `flutter analyze`, and `flutter test` on each push. Adapt the available Flutter GitHub Action or set up a self-hosted runner for desktop builds.

## Contributing

- Fork the repo, create a feature branch, make changes, add/adjust tests, and open a pull request.
- Keep changes small and focused. Run `flutter analyze` and `flutter test` before submitting.

## Notes for maintainers

- The project scaffold targets multiple platforms. When adding native plugins, verify multi-platform compatibility and test on each target you intend to support.

