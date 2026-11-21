# Orvia Deployment & Build Guide

This guide describes the reproducible procedures for building and packaging the **Orvia** cross-platform music player (Android & Windows) and deploying the production web application.

---

## 1. Prerequisites and Environment

### Toolchain Matrix
| Component | Minimum Version | Verified Local Environment |
|---|---|---|
| Flutter SDK | 3.29.0+ | Flutter 3.29.0 • channel stable |
| Dart SDK | 3.7.0+ | Dart 3.7.0 |
| Java JDK | OpenJDK 17 | Eclipse Adoptium OpenJDK 17.0.12 |
| Android SDK Platform | API 34 (Android 14) / 35 | Android SDK Tools 34.0.0 |
| Android NDK | 27.0.12077973 | Configured in `android/app/build.gradle` (`ndkVersion "27.0.12077973"`) |
| Visual Studio | 2022 Community / Build Tools | VS 2022 with C++ Desktop Development workload |
| Rust Toolchain | 1.82.0+ (stable-msvc & stable-android targets) | `cargo`, `rustc` |
| Node.js / npm | Node 18+ & npm 9+ | Node v20.x+ |

---

## 2. Quality Verification Before Any Build

Always execute static analysis and the full test suite before initiating production builds:

```bash
# 1. Run static analysis
flutter analyze

# 2. Run all unit and widget tests
flutter test --reporter expanded
```
*Current Verification Status:* 0 errors, 0 warnings. 150/150 tests passing.

---

## 3. Building Android Releases

### 3.1 Production Keystore Setup (Safe Procedure)
> [!IMPORTANT]
> Never commit `orvia.jks` or `android/key.properties` to version control. They are protected by `.gitignore`.

1. Generate a production key if one does not exist:
   ```bash
   keytool -genkeypair -v -keystore android/orvia.jks -alias orvia-key -keyalg RSA -keysize 4096 -validity 10000
   ```
2. Create `android/key.properties`:
   ```properties
   storePassword=<SECURE_STORE_PASSWORD>
   keyPassword=<SECURE_KEY_PASSWORD>
   keyAlias=orvia-key
   storeFile=../orvia.jks
   ```
   *Note: If `android/key.properties` is absent, Gradle automatically falls back to debug keystore signing.*

### 3.2 Android Build Commands
Sequential execution (never run concurrent Gradle/Rust builds):

```bash
# Universal Release APK
flutter build apk --release

# Split-per-ABI APKs (Recommended for smaller sideload downloads)
flutter build apk --release --split-per-abi
```

### 3.3 Output Artifacts
- **Universal APK:** `build\app\outputs\flutter-apk\app-release.apk`
- **ARM64-v8a APK:** `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`
- **armeabi-v7a APK:** `build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk`
- **x86_64 APK:** `build\app\outputs\flutter-apk\app-x86_64-release.apk`

### 3.4 Verification
```bash
# Check signing certificate (replace with actual path to apksigner)
apksigner verify --verbose --print-certs build\app\outputs\flutter-apk\app-release.apk

# Compute SHA-256
Get-FileHash -Algorithm SHA256 build\app\outputs\flutter-apk\app-release.apk
```

---

## 4. Building Windows Releases

### 4.1 Native Flutter & Rust Compilation
Ensure MSVC environment is initialized, then run:

```bash
flutter build windows --release
```

Compiled binaries are located at:
`build\windows\x64\runner\Release\`

### 4.2 Packaging Windows ZIP
Do **not** use PowerShell `Compress-Archive` because of zip-header anomalies with executables. Use the native Windows `tar.exe` (bsdtar):

```powershell
tar.exe -a -c -f "build\orvia-windows-x64-v3.0.4.zip" -C "build\windows\x64\runner\Release" *
```

### 4.3 Validation of Clean Extraction
Extract the ZIP into a clean temporary directory and verify that all dependencies are present:
- `orvia.exe`
- `flutter_windows.dll`
- `libmpv-2.dll`
- `libisar.dll`
- `rust_lib_orvia.dll`
- Plugin DLLs: `audio_service_win_plugin.dll`, `connectivity_plus_plugin.dll`, `dart_discord_rpc_plugin.dll`, `media_kit_libs_windows_video_plugin.dll`, `screen_retriever_windows_plugin.dll`, `url_launcher_windows_plugin.dll`, `window_manager_plugin.dll`
- `data\` folder containing Flutter assets and `app.so`.

---

## 5. Building & Deploying the Website (`ghpage`)

### 5.1 Local Static Build
```bash
cd ghpage
npm install
npm run build
```
The static output is generated into `ghpage/build/`.

### 5.2 Required Static Endpoints
Ensure the following files are present in `ghpage/static/` (which get copied into `ghpage/build/`):
- `version.json`: Up-to-date release manifest containing exact hashes, versions, and sizes.
- `banners.json`: Remote manifest for seasonal and curated banners.
- `repositories.json`: Plugin repository index.
- `.well-known/assetlinks.json`: Android Digital Asset Links statement for app-linking.
- `track.html` or `/track`: Deep-link landing page.

### 5.3 Deployment Execution
Deploy using the dedicated script:
```bash
python deploy_page.py
```
Or push the `ghpage/build` contents directly to GitHub Pages / Cloudflare Pages.
