# Build and Run

This page covers local builds and the artifacts the release workflow produces.
For signing secrets and publishing, see [Release process](../operations/release.md).

## Debug builds

```bash
flutter pub get
flutter run -d <device-id>
```

Useful debug targets:

```bash
flutter run -d windows
flutter run -d linux
flutter run -d macos
```

## Generated code

Regenerate localization files after editing ARB files:

```bash
flutter gen-l10n
```

Regenerate Isar/Freezed/build-runner outputs when the model layer changes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Regenerate Flutter Rust Bridge bindings after changing the Rust API:

```bash
flutter_rust_bridge_codegen generate
```

Do not edit generated files directly:

- `lib/l10n/app_localizations*.dart`
- `**/*.g.dart`
- `**/*.freezed.dart`
- `lib/src/rust/`

## Android

Build a universal release APK:

```bash
flutter build apk --release --build-number <build-number>
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

Build per-ABI APKs:

```bash
flutter build apk --release --split-per-abi --build-number <build-number>
```

Outputs:

- `app-armeabi-v7a-release.apk`
- `app-arm64-v8a-release.apk`
- `app-x86_64-release.apk`

For local release builds, configure a keystore and `android/key.properties`. Do
not commit either file. Without them, Gradle falls back to debug signing; do not
distribute those artifacts. The release workflow injects the keystore from
repository secrets.

Typical `key.properties` keys:

```properties
keyPassword=...
storePassword=...
keyAlias=...
```

The release workflow also verifies the APK signatures with `apksigner`.

## Windows

Run on Windows with the Visual Studio C++ workload installed:

```bash
flutter build windows --release --build-number <build-number>
```

Outputs are under `build/windows/x64/runner/Release/`. The release workflow
renames `orvia.exe` to `Orvia.exe` and zips the directory.

## Linux

Install the CI dependencies first:

```bash
sudo apt-get update
sudo apt-get install -y clang cmake git ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libstdc++-12-dev
```

Build:

```bash
flutter build linux --release --build-number <build-number>
```

Outputs are under `build/linux/x64/release/bundle/`. The release workflow packs
the bundle as a `.tar.gz`.

## iOS, macOS, and web

These platform folders exist in the repository, but they are not part of the
release workflow:

```bash
flutter build web
flutter build macos
flutter build ios
```

Treat these as experimental. Plugin runtime support, local music behavior, and
release packaging may be incomplete or untested.

## Versioning

The app version comes from `pubspec.yaml`:

```yaml
version: 3.0.4+0
```

The release workflow extracts the version and appends the CI run number as the
build number. Update `pubspec.yaml` and `CHANGELOG.md` together for a release.

## CI checks before merging

```bash
flutter analyze --no-fatal-infos
cargo check --manifest-path rust/Cargo.toml
```

The CI workflow currently runs these two commands. Running `flutter test` and
Rust tests locally is still recommended; see [Testing](testing.md).

## Clean rebuild

When generated files or native builds get out of sync:

```bash
flutter clean
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter run -d <device-id>
```
