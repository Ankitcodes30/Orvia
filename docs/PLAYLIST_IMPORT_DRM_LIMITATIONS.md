# Orvia Playlist Import & DRM / Authentication Boundaries

## 1. Overview
Orvia's playlist import system allows users to bring music from external platforms (YouTube, Spotify, and JioSaavn) into their local Orvia library.

Instead of violating platform terms or attempting to bypass Digital Rights Management (DRM), Orvia utilizes a metadata-first extraction and cross-resolver matching architecture:
1. **Metadata Extraction:** Extract playlist metadata (title, artwork, track names, artists, durations).
2. **Cross-Plugin Resolution:** Map each extracted track item to playable streams on user-configured content resolvers (such as JioSaavn).
3. **Local Library Persistence:** Save the matched tracks to the user's local SQLite database.

---

## 2. Platform Boundaries & DRM Limitations

### A. Spotify
- **DRM Protection:** Spotify's audio streams are encrypted using Widevine and FairPlay DRM. Orvia **never** decrypts, rips, or bypasses Spotify DRM streams.
- **Resolution Strategy:** Orvia extracts public playlist metadata (track title, artist, album, duration) and queries Orvia's content resolvers to find high-fidelity, playable audio matches.
- **Authentication:** Public and unlisted playlists can be extracted without login. Private playlists, algorithmic collections ("Made For You", "Discover Weekly"), and user favorites require Spotify OAuth authentication with user credentials, which are not accessible without user-authenticated developer app setup.

### B. YouTube & YouTube Music
- **Audio Extraction:** YouTube video audio is resolved via public or unlisted playlist metadata and playable stream URLs.
- **Boundaries & Geoblocking:**
  - Videos with age restrictions or requiring YouTube account sign-in cannot be retrieved anonymously.
  - Region-locked or copyright-blocked videos are omitted during extraction.
  - Video tracks are cleaned of non-music noise (e.g. `[Official Music Video]`, `(Lyrics)`) before resolution to ensure high-accuracy audio matches.

### C. JioSaavn
- **Native Direct Matching:** JioSaavn playlists and albums can be imported with exact track IDs, artist names, album titles, and high-resolution artwork (`500x500`).
- **Encrypted Media:** JioSaavn streams with encrypted DRM tokens are resolved directly through the official Rust JioSaavn plugin content resolver command, ensuring lawful playback.

---

## 3. Failure Handling & User Choice
- If a track cannot be resolved with high confidence (`< 0.45`), the track is flagged as unresolved.
- Users are presented with a review screen before saving, allowing manual selection of candidate matches or skipping unmatched songs.
- No existing user library data is ever overwritten or lost during an import operation.
