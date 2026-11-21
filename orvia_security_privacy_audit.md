# Orvia Security, Privacy & Licensing Audit

**Audit Date:** October 18, 2026  
**Audited Artifacts:** Orvia Application codebase (Flutter/Dart + Rust FFI), `ghpage` SvelteKit website, `website-lovable-source/orvia` React/TanStack Start source, distribution manifests, and build pipelines.

---

## 1. Executive Summary

| Category | Status | Risk Level | Remediated |
|---|---|---|---|
| Credentials & Secrets | Clean | None | Yes (no private keys in Git) |
| Network Transport Security | Hardened | Low | Yes (HTTPS enforced for manifests/updates) |
| Deep Links & URI Parsing | Hardened | Low | Yes (Graceful error handling & schema validation) |
| Android Signing Configuration | Caution | Medium | Documented (Debug-signed fallback until production key generated) |
| Authentication & Cloud Sync | Audited | Low | Documented (Explicitly labeled as local-only; guest mode intact) |
| Website Public Assets | Hardened | None | Yes (No leaked environment variables) |
| Licensing & Attribution | Compliant | Low | GPL-3.0 preserved; notices intact |

---

## 2. Secrets, API Keys and Credentials Audit

- **Git Tracking:** Verified that `.gitignore` properly excludes `*.jks`, `*.keystore`, `key.properties`, `.env`, and local credentials.
- **Source Code Scan:** Grep scans across Dart, Rust, Svelte, and TSX files identified **no** hardcoded private API keys, client secrets, or OAuth credentials.
- **Provider Access:** Music stream resolvers rely on public client contracts and provider APIs without circumventing DRM or authentication restrictions.

---

## 3. Network Transport & Update Integrity

- **Manifest Security (`OrviaUpdateService`):**
  - All manifest endpoints are strictly enforced to use `https://` (with exemptions only for local test endpoints `localhost`/`127.0.0.1`). Non-HTTPS URLs are rejected immediately.
  - Timeout safety: Configured with an 8-second resilient timeout, falling back gracefully to the verified GitHub raw mirror if `orvia.app` DNS resolution fails.
  - Checksum Enforcement: Release manifests specify SHA-256 hashes for all downloadable assets. `OrviaUpdateService` verifies byte sizes and SHA-256 integrity before signaling readiness to install.
- **Deep Link Validation (`OrviaDeepLinkService`):**
  - Parsing of `orvia://track/<id>` and web URLs (`https://orvia.app/track/<id>`) includes strict sanitization.
  - Malformed or unknown track IDs fail gracefully with friendly user alerts without crashing the player state machine.

---

## 4. Authentication, User Data & Cloud Sync

- **Guest Mode:** Orvia functions completely offline in guest mode without requiring user registration.
- **Local State vs Cloud Backend:**
  - The application stores user playlists, preferences, history, and favorites locally using Isar Database (`libisar`).
  - No fake cloud auth is presented to the user as real remote sync. If cloud features are developed in the future, they must be backed by a certified backend service.
  - Audio files and copyrighted media streams are never uploaded or synced to external servers.

---

## 5. Android Signing & Package Safety

- **Current Status:** In the local developer environment, `android/key.properties` and `android/orvia.jks` were absent. Gradle safely built release APKs using the fallback Android debug certificate.
- **Production Guardrail:**
  - Artifacts built with the debug certificate must **never** be labeled as production or pushed over existing installation channels.
  - A dedicated release guide (`orvia_release_and_rollback_guide.md`) outlines the steps for generating and preserving the official production keystore.

---

## 6. Website Security & Environment Configuration

- **Static Security:** The `ghpage` website uses SvelteKit with static export (`@sveltejs/adapter-static`), eliminating server-side attack vectors (no Node/SSR vulnerabilities).
- **Asset Links (`.well-known/assetlinks.json`):**
  - Configured with package name `ls.orvia.musicplayer` to associate official Android app-links with the web domain.
  - Fingerprint updated to match current build credentials; must be updated when official production release keystore is minted.
- **Environment Placeholders:** Created `ghpage/.env.example` with harmless template placeholders to ensure developers do not commit real deployment keys.

---

## 7. Open Source Licensing & Attribution

- **Primary License:** Orvia is distributed under the **GNU General Public License v3.0 (GPL-3.0)**.
- **Notices & Dependencies:**
  - Flutter engine, Rust crates, SvelteKit components, and UI icons (FontAwesome, Material Icons, Feather) retain their original MIT/Apache-2.0/GPL notices.
  - Developer identity is correctly attributed to **Ankit Kumbhare** (`Ankitcodes30`) while maintaining the original project's copyright legacy.
