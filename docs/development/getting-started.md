# Getting Started

This guide takes you from a fresh clone to a running debug build. For release
builds and signing, see [Build and run](build-and-run.md).

## Prerequisites

| Tool | Version / notes |
|---|---|
| Flutter | `3.35.4` stable (matches CI) |
| Dart | `>=3.3.0` (from `pubspec.yaml`) |
| Rust | Stable toolchain with `cargo` |
| Git | Any recent version |
| Android | JDK 17 and Android SDK; a device or emulator |
| Windows | Visual Studio with the **Desktop development with C++** workload |
| Linux | `clang cmake git ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev` |
| macOS | Xcode, only if experimenting with the macOS target |

Check your tools:

```bash
flutter --version
dart --version
rustc --version
cargo --version
```

## Clone and install dependencies

```bash
git clone https://github.com/Ankitcodes30/Orvia.git
cd Orvia
flutter pub get
```

The Flutter project depends on the local Rust crate through `rust_builder/`.
`flutter run` and `flutter build` invoke the Rust build automatically through
Cargokit. You do not need to build the Rust library separately for a normal run.

## Verify the Rust side

```bash
cargo check --manifest-path rust/Cargo.toml
```

This is the Rust check used by CI. If you change the Rust API, also regenerate
the Flutter Rust Bridge bindings.

## Regenerate Flutter Rust Bridge bindings

The bridge is configured in `flutter_rust_bridge.yaml`:

```yaml
rust_input: crate::api
rust_root: rust/
dart_output: lib/src/rust
```

Install the matching codegen if needed, then regenerate:

```bash
cargo install flutter_rust_bridge_codegen --version 2.12.0
flutter_rust_bridge_codegen generate
```

Do not edit files under `lib/src/rust/` by hand.

## Run the app

List available devices:

```bash
flutter devices
```

Run on a connected Android device or emulator:

```bash
flutter run -d <device-id>
```

Run on desktop:

```bash
flutter run -d windows
flutter run -d linux
flutter run -d macos
```

The Windows build must be run on Windows. Linux builds must be run on Linux.
Cross-compiling desktop targets from another OS is not supported by the project.

## First-run notes

- The app initializes Isar, the service locator, the Rust bridge, and the plugin
  system during bootstrap.
- Plugin-system initialization failure is non-fatal; the app can still start
  without plugin content.
- On Android, local music discovery needs audio/media permission.
- On desktop, local music uses folder scanning.
- The plugin bootstrap adds hosted repositories and may offer install-on-bootstrap
  plugins.

## Common setup problems

| Symptom | Likely cause / fix |
|---|---|
| `cargo: command not found` | Install Rust with `rustup` and reopen the terminal. |
| Rust bridge symbols missing or stale | Run `flutter_rust_bridge_codegen generate`; ensure the codegen version matches `flutter_rust_bridge: 2.12.0`. |
| Linux build fails on GTK/CMake | Install the Linux packages listed above. |
| Windows build cannot find a compiler | Install Visual Studio C++ desktop workload. |
| Android build fails on Java version | Use JDK 17, matching CI. |
| Generated Isar/Freezed files missing | Run `dart run build_runner build --delete-conflicting-outputs`. |
| Local music is empty | Grant media permission on Android or add music folders on desktop. |

## Next steps

- [Build and run](build-and-run.md)
- [Testing](testing.md)
- [Code style](code-style.md)
- [Architecture](../../ARCHITECTURE.md)
- [Plugin overview](../plugins/overview.md)
