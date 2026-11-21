# Orvia Release & Update Flow Guide

This document outlines the end-to-end release process for Orvia, covering versioning, artifact building, code signing, SHA-256 verification, manifest publishing, and update checker validation.

---

## 1. Release Manifest Specification

Orvia's in-app update checker queries an official release manifest hosted over HTTPS. The manifest supports stable and preview distribution channels, platform-specific binaries, release notes, minimum supported version enforcement, and SHA-256 checksums.

### Schema Structure (`release_manifest.json`)
```json
{
  "schema_version": 1,
  "app_name": "Orvia",
  "min_supported_version": "3.0.0",
  "channels": {
    "stable": {
      "version": "3.1.0",
      "build_number": 1,
      "release_notes": "Highlights of this release...",
      "published_at": "2026-10-17T00:00:00Z",
      "platforms": {
        "android": {
          "download_url": "https://your-domain.com/downloads/orvia-v3.1.0.apk",
          "sha256": "abcdef0123456789...",
          "file_size": 25412300
        },
        "windows": {
          "download_url": "https://your-domain.com/downloads/orvia-v3.1.0-windows.zip",
          "sha256": "abcdef0123456789...",
          "file_size": 34120000
        }
      }
    },
    "preview": {
      "version": "3.2.0-preview.1",
      "build_number": 2,
      "release_notes": "Experimental preview release...",
      "published_at": "2026-10-17T00:00:00Z",
      "platforms": {
        "android": {
          "download_url": "https://your-domain.com/downloads/orvia-v3.2.0-preview.1.apk",
          "sha256": "abcdef0123456789..."
        }
      }
    }
  }
}
```

---

## 2. Step-by-Step Release Workflow

### Step 1: Update App Version
In `pubspec.yaml`, update the version string and build number according to semantic versioning:
```yaml
version: 3.1.0+1
```
- `3.1.0` maps to Android `versionName`.
- `1` maps to Android `versionCode`.

### Step 2: Build and Sign the Release APK
Android requires every APK update to be signed with the exact same cryptographic key as the currently installed version. If the signature key differs, the Android Package Manager will refuse the update with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.

1. Ensure your release keystore configuration is defined in `android/key.properties`:
   ```properties
   storePassword=<keystore-password>
   keyPassword=<key-password>
   keyAlias=<key-alias>
   storeFile=/path/to/upload-keystore.jks
   ```
2. Build the release APK (using APK Signature Scheme v2/v3):
   ```bash
   flutter build apk --release
   ```
   Output: `build/app/outputs/flutter-apk/app-release.apk`

### Step 3: Compute SHA-256 Checksum
Calculate the exact SHA-256 hash of the generated APK file:
- On Linux / macOS:
  ```bash
  sha256sum build/app/outputs/flutter-apk/app-release.apk
  ```
- On Windows PowerShell:
  ```powershell
  Get-FileHash -Algorithm SHA256 .\build\app\outputs\flutter-apk\app-release.apk
  ```

### Step 4: Publish Binary to Secure Hosting
Upload the signed APK to your verified CDN or hosting storage (e.g. SourceForge, official web host, or cloud bucket). **Always use HTTPS.** Never use unverified or temporary third-party file hosts.

### Step 5: Update and Publish `release_manifest.json`
1. Update `release_manifest.json` with:
   - `version`: The new version string matching `pubspec.yaml`.
   - `build_number`: The integer build number.
   - `download_url`: The direct HTTPS download URL.
   - `sha256`: The 64-character lowercase hexadecimal hash computed in Step 3.
   - `release_notes`: Clear release notes describing bug fixes and new features.
   - `min_supported_version`: Baseline minimum version if older versions are deprecated.
2. Publish `release_manifest.json` to the root of your official domain (e.g., `https://your-domain.com/release_manifest.json`).

### Step 6: Verify the In-App Update Checker
1. Launch Orvia on a test device or desktop build.
2. In **Settings -> Updates**:
   - Ensure the manifest URL points to your published manifest.
   - Tap **Check for updates**.
   - Verify that the app detects the new version, displays the release notes, and confirms the SHA-256 integrity check upon download.
3. Test edge cases:
   - Verify that an up-to-date app displays "Orvia is up to date".
   - Verify that network interruptions or invalid URLs display "Unable to check for updates" with a retry button instead of falsely claiming "up to date".

---

## 3. Security Boundaries & Android Integrity

### A. Integrity vs Authentication
- **SHA-256 Verification:** The SHA-256 checksum proves byte integrity between the manifest and the downloaded file (protecting against incomplete downloads or corrupted transfers). However, SHA-256 alone does not independently authenticate the software author without a trusted HTTPS transport.
- **Android Signing Authority:** The true authenticity guarantee on Android is provided by Android's cryptographic APK signing certificate. Android's OS package manager (`PackageManager`) verifies that the new APK is signed with the identical certificate embedded in the installed application. Any APK signed with a different key will be rejected at installation time with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.

### B. Package ID Continuity
- Orvia's Android application ID is `ls.orvia.musicplayer` (defined in `android/app/build.gradle.kts`).
- Future releases must maintain `ls.orvia.musicplayer` without modification. Changing the package ID causes Android to treat the new build as a separate application, breaking in-place updates and database persistence.

### C. Non-Automated User Installation
- Orvia does not automate silent background APK installation or bypass platform security boundaries.
- Users are directed to the official download link or prompted to confirm installation through the standard Android Package Installer intent, ensuring complete transparency and user consent.
