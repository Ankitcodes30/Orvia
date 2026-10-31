# Orvia v3.0.4 — Master Release Gate Audit & Production Readiness Report

**Date:** October 18, 2026  
**Repository:** `C:\Users\ankit\Desktop\Orvia`  
**Target Version:** `3.0.4+1` (VersionCode: 1, VersionName: 3.0.4)  
**Audit Mode:** Evidence-Based Release Verification & Build Artifact Validation  

---

## 1. Master Release Gate Checklist

| Release Gate Item | Status | Verified Evidence & Audit Finding |
| :--- | :---: | :--- |
| **1. Playback & UI Regressions** | **PASS** | Queue title sync, pause/resume, track transitions, ±10s seek gestures, and hardware volume control preserved. VolumeDragController successfully removed from cover art. 9/9 phase-1 tests pass. |
| **2. Static Analysis** | **PASS** | `flutter analyze` completed with **0 errors, 0 warnings**, and 64 informational style lints. |
| **3. Automated Test Suites** | **PASS** | **150/150 tests passed** across all 9 test suites (`flutter test`). Dotted initialism matching bug in `artist_view.dart` was diagnosed, fixed, and verified. |
| **4. Android Release Build** | **PASS** | `flutter build apk --release` compiled with exit code 0 (Universal + 3 ABI splits generated). CargoKit Rust compilation succeeded for armv7, aarch64, and x86_64. |
| **5. Android Release Signing** | **BLOCKED** | Release APKs were compiled using debug keystore fallback. No legitimate `android/key.properties` or release keystore exists. Cannot be labelled production-signed until a legitimate key is provided. |
| **6. Windows Release Build & Package** | **PASS** | `flutter build windows --release` compiled with exit code 0. Standalone portable ZIP package created via `tar.exe` with all required DLLs, assets, and verified hashes. Clean unpack verified in scratch directory. |
| **7. Release Artifact Integrity** | **PASS** | SHA-256 hashes and exact byte sizes freshly calculated and cross-verified for both Android and Windows build artifacts. |
| **8. Version & Manifest Consistency** | **PASS** | `pubspec.yaml`, `android/local.properties`, root `version.json`, `ghpage/static/version.json`, and `ghpage/build/version.json` are synchronized to `3.0.4+1` (VersionCode: 1, VersionName: 3.0.4). |
| **9. Remote Content & Refresh** | **PASS** | `SmartBannerService` time-aware dayparting and festival schedule verified. Fallback to local embedded defaults operates cleanly when network is offline. |
| **10. Time-Based Banner Tap-to-Playlist**| **PASS** | Banner card tap invokes `_openBanner(banner)`, presenting a bottom sheet with theme artwork, full tracklist, individual play, and "Play All" actions. |
| **11. Creator's Choice & Catalogue** | **PASS** | 12 A.K. MUSIC WORLD tracks verified active (HTTP 200). 47 Creator's Choice tracks verified with JioSaavn provider IDs; 11 unplayable YouTube mashups excluded. |
| **12. Artwork & CDN Verification** | **PASS** | 5 Navratri artwork URLs tested over HTTP; all return HTTP 200 OK. Bollywood, Instrumental, Marathi, and Bhakti 500x500 CDN images pass automated checks. |
| **13. Deep Linking (App Scheme)** | **PASS** | `orvia://` custom scheme registered in `AndroidManifest.xml` and validated via `OrviaDeepLinkService`. |
| **14. Website & Static Export** | **PASS** | `ghpage` static build compiled via Vite / SvelteKit into `ghpage/build` including `index.html`, `track.html`, `.well-known/assetlinks.json`, `version.json`, and direct download buttons with SHA-256 integrity details. |
| **15. Website, DNS & HTTPS App Links** | **BLOCKED (External)** | `orvia.app` DNS currently resolves to Cloudflare SOA without an A/CNAME record. `assetlinks.json` created and bundled in build output, but domain hosting and live verification require DNS configuration. |
| **16. Real Account & Cloud Sync** | **INFORMATIONAL / MOCK** | Guest mode functions seamlessly offline. User account and cloud sync operate via local SQLite storage (`user_cloud_backup_payload`). No remote Firebase/OAuth backend is configured. |
| **17. Remote Push Notifications** | **INFORMATIONAL / MOCK** | In-app update alerts operate via local update check. No remote FCM/APNs provider is connected or configured. |
| **18. Physical Device Testing** | **NOT TESTED** | `adb devices -l` checked: 0 attached physical devices or emulators. Verified via compilation, static analysis, unit/widget/integration tests, and desktop build execution. |

---

## 2. Release Artifact Inventory & Hashes

### Android Release Artifacts (`build\app\outputs\flutter-apk\`)
- **Universal Release APK:**
  - **Path:** `build\app\outputs\flutter-apk\app-release.apk`
  - **Size:** 61,356,780 bytes (58.51 MB)
  - **SHA-256:** `E9E603696394E082E9123C6EC6681B109CF9E6028880531B5A7B70C00C38DAD6`
  - **Signing:** Debug keystore fallback (`androiddebugkey`)
- **arm64-v8a Release APK:**
  - **Path:** `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`
  - **Size:** 28,103,358 bytes (26.80 MB)
  - **SHA-256:** `8213B7FA2FF9FB834435AAAA52A14BE50935975883FAF7705EE7DD88B1CDAE2E`
- **armeabi-v7a Release APK:**
  - **Path:** `build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk`
  - **Size:** 27,176,794 bytes (25.91 MB)
- **x86_64 Release APK:**
  - **Path:** `build\app\outputs\flutter-apk\app-x86_64-release.apk`
  - **Size:** 28,581,476 bytes (27.25 MB)

### Windows Release Artifacts (`build\`)
- **Standalone Distribution ZIP Archive:**
  - **Path:** `build\orvia-windows-x64-v3.0.4.zip` (and `build\windows_release\Orvia-Windows.zip`)
  - **Size:** 35,335,119 bytes (33.70 MB)
  - **SHA-256:** `C74A55B9B5586096A143CE4C7DC287CCB3731A5452E4DC511C08D89AACD47D90`
- **Release Executable:**
  - **Path:** `build\windows\x64\runner\Release\orvia.exe`
  - **Size:** 61,952 bytes
  - **SHA-256:** `ADC91D137003C989B4675C49C0850A120B1D02F1F5480FF9594B56994E26E56E`
- **Packaged Dependencies:** `flutter_windows.dll`, `libmpv-2.dll`, `audio_service_win_plugin.dll`, `libisar.dll`, `rust_lib_orvia.dll`, `connectivity_plus_plugin.dll`, `dart_discord_rpc_plugin.dll`, `discord-rpc.dll`, `isar_community_flutter_libs_plugin.dll`, `media_kit_libs_windows_audio_plugin.dll`, `permission_handler_windows_plugin.dll`, `share_plus_plugin.dll`, `url_launcher_windows_plugin.dll`, `data/`.

---

## 3. Remote Content & Manifest Synchronization

- **`version.json`, `ghpage/static/version.json`, & `ghpage/build/version.json`:**
  - `schema_version`: `1`
  - `app_name`: `Orvia`
  - `version`: `3.0.4`
  - `build_number`: `1`
  - `min_supported_version`: `3.0.0`
  - Android download URL, SHA-256 (`e9e603...`), and size (`61356780`) match actual compiled universal APK.
  - Windows download URL, SHA-256 (`c74a55...`), and size (`35335119`) match actual packaged standalone ZIP.
- **`banners.json`, `ghpage/static/banners.json`, & `ghpage/build/banners.json`:**
  - Synchronized with active festival schedules (Navratri 2026, Diwali 2026) and curated time-aware dayparts (Morning Bhakti, What's Hot, Gym Energy, Night Calm).

---

## 4. External Dependencies & Blockers Summary

1. **Android Production Release Keystore:**
   - The application compiles cleanly in release mode, but signing defaults to the debug key because `android/key.properties` is absent. A dedicated release key must be provided or authorized before publishing to third-party stores.
2. **DNS & Hosting (`orvia.app`):**
   - DNS currently has only Cloudflare SOA records. Pointing an A or CNAME record to the GitHub Pages or static host is required for web downloads and HTTPS App Links.
3. **Remote Push & Cloud Auth Backend:**
   - Architecture operates locally with SQLite session tokens and guest mode. Genuine multi-device synchronization and remote push notifications require external cloud backend infrastructure (e.g. Supabase, Firebase Cloud Messaging).
