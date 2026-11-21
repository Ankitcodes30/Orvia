# Orvia Release & Rollback Guide

This document defines the release lifecycle, versioning conventions, production signing procedures, and emergency rollback protocols for the **Orvia** project.

---

## 1. Versioning Conventions

Orvia uses [Semantic Versioning 2.0.0](https://semver.org/) with build metadata:
`MAJOR.MINOR.PATCH+BUILD_NUMBER`

- **MAJOR**: Incompatible database migrations, major architectural redesigns, or breaking API changes.
- **MINOR**: New features, new music providers, or significant UX enhancements.
- **PATCH**: Bug fixes, security patches, and minor UI polishes.
- **BUILD_NUMBER**: Monotonically increasing positive integer representing the Android `versionCode` and update comparator.

### Current Version Alignment
- `pubspec.yaml`: `version: 3.0.4+1`
- `android/local.properties`: `flutter.versionCode=1`, `flutter.versionName=3.0.4`
- `version.json`: `"version": "3.0.4"`, `"build_number": 1`

---

## 2. Production Android Signing Key Management

> [!CAUTION]
> Once a release APK signed with a production keystore is distributed to users, changing or losing the keystore will **permanently break in-place updates** for all existing installs (Android enforces signature continuity on APK replacement).

### 2.1 Generating Official Release Keystore
Generate a 4096-bit RSA key pair with a 25+ year validity:
```bash
keytool -genkeypair -v \
  -keystore android/orvia.jks \
  -alias orvia-key \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
```

### 2.2 Keystore Backup & Security
1. Store the `.jks` file in a secure, encrypted offline vault.
2. Record the keystore password, alias, and key password in an enterprise password manager.
3. Configure `android/key.properties` (strictly ignored by `.gitignore`):
   ```properties
   storePassword=<PASSWORD>
   keyPassword=<PASSWORD>
   keyAlias=orvia-key
   storeFile=../orvia.jks
   ```

---

## 3. Step-by-Step Release Workflow

1. **Verify Code Quality:**
   ```bash
   flutter analyze
   flutter test
   ```
2. **Build Release Binaries:**
   - Android: `flutter build apk --release && flutter build apk --release --split-per-abi`
   - Windows: `flutter build windows --release`
3. **Package Windows Distribution:**
   ```powershell
   tar.exe -a -c -f "build\orvia-windows-x64-v3.0.4.zip" -C "build\windows\x64\runner\Release" *
   ```
4. **Compute Cryptographic Hashes & File Sizes:**
   ```powershell
   Get-FileHash -Algorithm SHA256 build\app\outputs\flutter-apk\app-release.apk
   Get-FileHash -Algorithm SHA256 build\orvia-windows-x64-v3.0.4.zip
   ```
5. **Update Release Manifests:**
   Update `version.json` and `ghpage/static/version.json` with the exact SHA-256 strings and byte sizes.
6. **Build Website:**
   ```bash
   cd ghpage && npm run build
   ```
7. **Deploy & Tag:**
   Create a signed Git tag (e.g., `v3.0.4+1`) and publish release assets to GitHub Releases / distribution server.

---

## 4. Emergency Rollback Procedures

### 4.1 Client Update Rollback (Manifest-driven)
If a critical regression is discovered in a published release:
1. Do **not** decrement version numbers in `version.json` (clients will not downgrade APKs automatically if the local build number is higher).
2. **Fast-Forward Emergency Patch (Recommended):**
   - Fix the blocker on a hotfix branch.
   - Bump version to `3.0.4+2` (or `3.0.5+2`).
   - Build, verify, update `version.json`, and publish immediately.
3. **Emergency Disabling of Update Alerts:**
   - Update `version.json` on the server so `version` and `build_number` point back to the previous stable release, or set `"min_supported_version"` appropriately to prevent incompatible features from running.

### 4.2 Website Rollback
If the live website encounters an outage:
1. Re-deploy the previously verified build artifacts from `ghpage/build/` using `python deploy_page.py`.
2. Check CDN caching / Cloudflare cache purge to invalidate stale assets immediately.

### 4.3 Database Schema Rollback Safety
- Isar migrations must always be forward-compatible.
- Never drop database tables or columns without fallback logic in the DAO layer.
- Ensure that users reinstalling or rolling back do not suffer data corruption.
