# Orvia — Task Recovery & Consolidated Requirements Audit Report

**Date:** October 18, 2026  
**Workspace:** `C:\Users\ankit\Desktop\Orvia`  
**Repository:** `Ankitcodes30/Orvia` (branch `main`)  
**Target Version:** `3.0.4+1` (VersionCode: 1, VersionName: 3.0.4)

---

## 1. Recovered Requirements & Sources of Evidence

- **Baseline Sources Examined:**
  - Git repository log (`13b0355`, `1ba84eb`, `66d42ef`, `8d86c9d`, `d7c88c5`).
  - Active workspace modifications and untracked files across `lib/`, `android/`, `ghpage/`, and `test/`.
  - Prior session reports and artifacts (`creators_choice_report.md`, `orvia_release_gate_audit.md`).
  - Automated test runs: **150/150** unit, widget, and integration tests passed.
  - Static analysis: **0 errors, 0 warnings**, 64 informational lints (`flutter analyze`).
  - Real hardware verification: `adb devices -l` inspected via Android SDK platform-tools; no physical device attached (status: NOT TESTED on physical device).
  - Production build pipeline: Android release APKs and Windows release standalone archive successfully compiled and verified.
  - Website static distribution: SvelteKit production build compiled to `ghpage/build` including `.well-known/assetlinks.json`, `version.json`, `banners.json`, and `track.html`.

---

## 2. Existing Changes Preserved

All tracked and untracked modifications have been strictly preserved:
- **Audio & Playback Pipeline:**
  - `lib/services/player/queue_manager.dart`: Queue titles and playback track synchronisation preserved.
  - `lib/services/orvia_player.dart`: Unsafe vertical volume-drag on album cover removed; double-tap ±10s seek and hardware volume keys retained.
  - `lib/screens/screen/player_screen.dart`: VolumeDragController removed; lyrics and playback gestures intact.
  - `lib/screens/widgets/smart_replace_dialog.dart` & `more_bottom_sheet.dart`: Safe queue replacement and in-place track replacement with `preserveTitle: true`.
- **Catalogue & Identity:**
  - `lib/screens/screen/common_views/artist_view.dart`: Verified dotted initialism filtering for "A.K. MUSIC WORLD" (`a.k.musicworld`) vs unpunctuated homonym channels.
  - `lib/services/catalogue/curated_playlists_service.dart`: 12 verified genuine A.K. MUSIC WORLD tracks mapped to `content-resolver.bloomfactory.ytvideo`; 7 unavailable tracks safely excluded.
  - `lib/screens/widgets/navratri_special_card.dart` & `bhakti_section.dart`: Verified 5 Navratri tracks with active high-resolution 500x500 CDN artwork (all returning HTTP 200).
- **Remote Manifest & Updater Services:**
  - `lib/services/updater/orvia_update_service.dart`: SemVer 2.0.0 parser with Android build number comparison; fails safe on 404/DNS error (never falsely reports "up to date").
  - `lib/services/banner/smart_banner_service.dart`: Time-aware sliding banners with dayparting heuristics and local fallback.
  - `lib/screens/widgets/smart_sliding_banners.dart`: Interactive banner tap (`_openBanner`) presents modal playlist sheet with theme artwork, song list, and "Play All" playback action.
- **Account & Notification Modules:**
  - `lib/services/account/account_service.dart`: Local guest mode architecture with SQLite user session tokens and offline data snapshot.
  - `lib/services/notification/push_notification_service.dart`: Android 13+ runtime permission handling and local update alerts.

---

## 3. Task State Breakdown

| Category | Item | State | Evidence |
| :--- | :--- | :---: | :--- |
| **Playback & Safety** | Queue Title Sync | **PASS** | 9/9 tests pass in `test/phase1_playback_state_and_volume_safety_test.dart`. |
| **Playback & Safety** | Volume Drag Removal | **PASS** | `VolumeDragController` reference cleanly excised from cover art. |
| **UI & Navigation** | Installer First-Launch Minimization | **PASS** | Guard in `MainActivity.kt` (`!isTaskRoot && Intent.ACTION_MAIN`) terminates secondary launcher tasks. |
| **UI & Navigation** | Navigation & Pull-to-Refresh | **PASS** | `LoadCharts(bypassCache: true)` and `PrefetchAllChartDetails(forceRefresh: true)` verified. |
| **Time-Based Banners** | Tap-to-Playlist Action | **PASS** | `_openBanner(banner)` modal displays theme art, title, tracks list, individual play, and "Play All" actions. |
| **Artist Catalogue** | A.K. MUSIC WORLD Verification | **PASS** | 12 genuine piano tracks verified (HTTP 200). Homonym channel isolation verified in regression tests. |
| **Artwork Verification**| Navratri Special 5 Tracks | **PASS** | All 5 CDN artwork URLs (Dulhaniya Re, Aalha Ki Dhwaja, Bigdi Meri Bana De, Nach Rahi Hai Kali Angana, Angna Padharo) return HTTP 200. |
| **Curated Playlists** | Bollywood, Instrumental, Marathi, Bhakti | **PASS** | Verified active CDN artwork; count mismatches reconciled; deduplicated in browse categories. |
| **Curated Playlists** | Creator's Choice (47 Tracks) | **PASS** | 47 tracks validated with JioSaavn composite IDs; 11 YouTube-exclusive mashups excluded per strict playback safety rules. |
| **Curated Playlists** | Dammn Feature Decommission | **PASS** | `ensurePlaylistExists` retired; no unwanted auto-seeding into user library. |
| **Remote Content** | Version & Banner Manifests | **PASS** | `version.json` and `banners.json` present in root, `ghpage/static/`, and `ghpage/build/` with matching schemas. |
| **Deep Linking** | `orvia://` App Scheme | **PASS** | Intent filter registered and tested via `OrviaDeepLinkService`. |
| **Deep Linking** | HTTPS App Links (`https://orvia.app/`) | **BLOCKED (External)** | Requires DNS resolution for `orvia.app` and domain hosting of `.well-known/assetlinks.json`. |
| **Cloud & Auth** | Guest Mode & Local Snapshot | **PASS** | Works completely offline without blocking core playback. |
| **Cloud & Auth** | Remote Multi-device Cloud Sync | **INFORMATIONAL / MOCK** | Backed by local SQLite (`user_cloud_backup_payload`). No external cloud/OAuth backend configured. |
| **Push Notifications**| In-app Update Alerts | **PASS** | Verified in `OrviaUpdateService`. |
| **Push Notifications**| Remote Push (FCM / APNs) | **INFORMATIONAL / MOCK** | No Firebase/APNs provider configured; operates via local app resume checks. |
| **Physical Device Test**| Real Android Device Check | **NOT TESTED** | `adb devices -l` returns 0 connected devices; tested via compilation, desktop execution, and test suites. |

---

## 4. Current Build & Distribution Status

1. **Static Analysis:**
   - 0 errors, 0 warnings, 64 informational lints (`flutter analyze`).
2. **Automated Test Suites:**
   - 150/150 tests passing (`flutter test`).
3. **Android Release Build:**
   - Universal APK: `build\app\outputs\flutter-apk\app-release.apk` (61,356,780 bytes, SHA-256: `E9E603696394E082E9123C6EC6681B109CF9E6028880531B5A7B70C00C38DAD6`).
   - ABI Splits: `app-arm64-v8a-release.apk` (28.1 MB), `app-armeabi-v7a-release.apk` (27.2 MB), `app-x86_64-release.apk` (28.6 MB).
   - Signing: Debug keystore fallback (no production `android/key.properties` or release keystore present).
4. **Windows Release Build & Packaging:**
   - Standalone Archive: `build\orvia-windows-x64-v3.0.4.zip` (35,335,119 bytes, SHA-256: `C74A55B9B5586096A143CE4C7DC287CCB3731A5452E4DC511C08D89AACD47D90`).
   - Copied to `build\windows_release\Orvia-Windows.zip`.
   - Executable: `build\windows\x64\runner\Release\orvia.exe` (61,952 bytes, SHA-256: `ADC91D137003C989B4675C49C0850A120B1D02F1F5480FF9594B56994E26E56E`).
   - Clean unpack test: Verified in temporary directory; all runtime DLLs, data assets, and executable extracted cleanly.
5. **Website Static Build:**
   - Directory: `ghpage/build` compiled via Vite / SvelteKit static adapter.
   - Includes: `index.html`, `track.html`, `banners.json`, `version.json`, `.well-known/assetlinks.json`, `repositories.json`, `CNAME`.

---

## 5. Exact External Blockers & Next Actionable Steps

1. **Production Signing Keystore (Android):**
   - *Status:* Blocked on developer authorization/provision of production release keystore and `android/key.properties`. Current release APK is signed with debug key.
2. **DNS & Hosting (`orvia.app`):**
   - *Status:* `orvia.app` DNS contains only an SOA record pointing to Cloudflare nameservers (`fatima.ns.cloudflare.com`). No A or CNAME record is configured.
   - *Action Required:* Configure Cloudflare DNS A/CNAME record to point to GitHub Pages or static host.
3. **Git Remote & Deployment:**
   - *Status:* Local repository has no Git remote configured (`git remote` is empty).
   - *Action Required:* Add `origin` remote (`git remote add origin https://github.com/Ankitcodes30/Orvia.git`) and push to publish release tags and website.
