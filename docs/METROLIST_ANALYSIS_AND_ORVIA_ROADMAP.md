# Metrolist Analysis & Orvia Feature Enhancement Roadmap

## 1. Executive Summary & Savepoint Status

- **Repository**: `C:\Users\ankit\Desktop\Orvia`
- **Git Savepoint**: 
  - Remote Branch: `origin/savepoint/pre-metrolist-enhancements`
  - Git Tag: `v3.0.7-pre-metrolist`
  - Active Development Branch: `feature/metrolist-enhancements`
  - Desktop Standalone Backup Archive: `D:\Orvia_Complete_Project_Backup.zip` (209.3 MB)
- **Status**: The current working state of Orvia is 100% safeguarded. Any experimental implementation can be instantly rolled back without risking existing user data or production builds.

---

## 2. Metrolist Deep Dive (Deconstructed from Source Code & Screenshots)

Metrolist is a Kotlin Multiplatform (KMP) + Compose Multiplatform music streaming application. Here is how each of its standout features is implemented under the hood:

### A. Initial Setup / Onboarding Flow (6 Steps)
As captured in your screenshots:
1. **Step 1 - Welcome**: Clean Material Design 3 Expressive intro. Explains privacy and system permissions before initial playback.
2. **Step 2 - Privacy & Diagnostics (Sentry)**: Explicit opt-in for telemetry. Guarantees no tokens, cookies, or user URLs are collected.
3. **Step 3 - System Permissions**: Requests `POST_NOTIFICATIONS` for foreground media service and download progress notifications.
4. **Step 4 - Language and Region**:
   - App language selection.
   - **Translate lyrics**: Auto-translates foreign lyrics into user language.
   - **Show romanization**: Converts Japanese Kanji/Hiragana, Korean Hangul, Cyrillic, Hindi/Devanagari into English/Latin script.
   - **Larger text preference**: Lets user choose whether the original lyrics or the romanized text is larger.
5. **Step 5 - Playback & Casting**: Toggles background discovery for Chromecast, Google Cast, and Sonos/DLNA speakers.
6. **Step 6 - Completion**: Marks `first_run_completed` in persistent settings and launches directly into the home screen.

### B. Track Sources & Recommendation Engine
- **InnerTube YouTube Music Integration**: Metrolist communicates directly with YouTube Music's InnerTube endpoints:
  - `https://music.youtube.com/youtubei/v1/browse` using client `WEB_REMIX` / `ANDROID_MUSIC`.
  - **Mood & Genre Chips**: Extracted from `FEmusic_home` -> `sectionListRenderer` -> `ChipCloudRenderer`. Chips include **Podcasts**, **Romance**, **Feel good**, **Workout**, **Relax**, **Energize**.
  - Clicking any chip reloads the shelf with personalized mood-specific recommendations directly from YouTube's recommendation model.
  - **Shelves / Carousels**: Parses `musicCarouselShelfRenderer` into high-fidelity carousels: "Quick picks", "Mixed for you", "Forgotten favorites", "Similar to [Artist]".
  - **Instant Search Suggestions**: Queries `/youtubei/v1/search` with a 150ms debounce, returning instant auto-completions before the user even finishes typing.

### C. 3x3 Speed Dial Grid + Surprise Dice Roll
- **Layout**: 3 rows $\times$ 3 columns grid on the Home screen.
- **Slots 1 to 8**: Frequently played tracks, pinned albums, and playlists with album art thumbnails and badges.
- **Slot 9 (Interactive Dice)**:
  - Displays an expressive 5-dot dice button.
  - When tapped, triggers a haptic pulse (`HapticEvent.DICE_ROLL`), animates a 3D morphing dice-roll rotation (`SpeedDialRollMotion`), and randomly picks a high-energy surprise song from your library or launches an instant YouTube radio station.
  - Paged horizontally (`HorizontalPager`) with smooth dot indicators (`• • •`).

### D. Synchronized Lyrics & Romanization
- **Provider (LRCLIB)**:
  - Fetches from `https://lrclib.net/api/get` (title, artist_name, album_name, duration).
  - Open-source, rate-limit friendly, zero API key needed.
  - Returns `syncedLyrics` in standard `.lrc` format (`[mm:ss.xx] lyric line`) and `plainLyrics`.
- **Romanization Engine**:
  - Uses `Glyphmind` transliteration engine.
  - Dynamically romanizes non-Latin characters (Japanese, Korean, Chinese, Arabic, Cyrillic) into easy-to-sing Latin phonetics.

### E. Player Audio & Video Mode Switcher
- In Metrolist's player bar and full player, a dedicated toggle button switches between **Audio Only** and **Music Video**.
- YouTube provides both audio-only streams (itag 251 Opus / itag 140 M4A) and video streams (itag 18/22 720p/1080p).
- When "Video" is enabled, the artwork surface is replaced by a hardware-accelerated video view, maintaining seamless playback position across the switch.

### F. Tempo & Pitch Adjustment
- Embedded in the song options bottom sheet:
  - **Tempo / Speed**: Slider from $0.5\times$ to $2.0\times$ with presets ($0.75\times$, $1.0\times$, $1.25\times$, $1.5\times$).
  - **Pitch Shift**: Slider adjusting pitch by $-12$ to $+12$ semitones (or fine-tuning in cents) without altering song speed (Sonic / WSOLA time-stretching).

### G. Listening History & Statistics Section
- **Top Bar**: Dedicated **History** icon (clock counter-clockwise) and **Statistics** icon (barchart/profile).
- **Listening History**: Chronological timeline of every track played with exact date/time, album art, and play count.
- **Statistics Dashboard**:
  - Total listening minutes (Daily, Weekly, Monthly, All-time).
  - Top 5 Tracks, Top 5 Artists, and Top Albums.
  - Visual charts (listening trends, genre distribution).

### H. "Listen Together" (Live Synchronized Rooms)
- Protocol defined in `Protocol.kt` over WebSockets (`wss://`):
  - `create_room` / `room_created`: Host creates a room with an alphanumeric join code.
  - `join_room` / `join_request` / `approve_join`: Friends join via the code; host can require approval.
  - `sync_playback`: Broadcasts current track ID, track position (ms), server timestamp, and play state.
  - **Clock Drift Compensation**: Uses `ping`/`pong` round-trip time measurements to adjust the client clock so all phones play audio in perfect unison ($\pm 15\text{ms}$).
  - `suggest_track`: Participants can browse songs and suggest additions to the host's queue.
  - `kick_user` / `transfer_host`: Full room management controls.

---

## 3. Orvia Mapping & Implementation Architecture

Because Orvia is built with **Flutter + BLoC + media_kit**, we can implement all of these features natively without fragile workarounds:

| Feature | Metrolist Technology | Orvia (Flutter / Dart) Architecture |
| :--- | :--- | :--- |
| **Onboarding (6 steps)** | Compose `HorizontalPager` | Flutter `PageView` + `OnboardingCubit` + `SharedPreferences` |
| **Chips / Recommendations** | YouTube `FEmusic_home` InnerTube | Direct InnerTube Client in Dart (`YouTubeExploreService`) -> `ExploreCubit` |
| **3x3 Speed Dial + Dice** | Compose Grid + `Animatable` | `GridView.count(crossAxisCount: 3)` + Animated Dice Widget + HapticFeedback |
| **Synced Lyrics** | LRCLIB API | `LrcLibLyricsService` + `LrcParser` + `ScrollableLyricsView` in `fullscreen_lyrics_view.dart` |
| **Romanization** | Glyphmind KMP | `unidecode` / phonetic transliteration helper in Dart |
| **Audio/Video Switcher** | Media3 PlayerView | `media_kit_video` `Video(controller: _videoController)` |
| **Tempo & Pitch** | ExoPlayer Sonic | `media_kit` `player.setRate(speed)` & `player.setPitch(pitch)` (Natively supported by MPV!) |
| **History & Statistics** | Room DB + Compose Charts | Drift `history_dao.dart` + `fl_chart` or custom canvas statistics dashboard |
| **Listen Together** | Ktor WebSockets | `web_socket_channel` + `ListenTogetherService` + clock sync drift corrector |

---

## 4. Step-by-Step Implementation Roadmap

1. **Phase 1: Speed Dial 3x3 Grid & Animated Surprise Dice**
   - Add Speed Dial section to `explore_screen.dart`.
   - Implement the 8-item + 1-dice layout with shuffle/radio launch.
2. **Phase 2: YouTube Mood/Genre Chips & Instant Search Suggestions**
   - Add Category chips bar (Podcasts, Romance, Feel good, Workout, Relax, Energize).
   - Hook instant debounced suggestions to the search view.
3. **Phase 3: LRCLIB Synced Lyrics & Transliteration**
   - Integrate LRCLIB as a first-class lyrics provider in `LyricsCubit`.
   - Support synchronized karaoke-style highlighting with Romanization toggle.
4. **Phase 4: Player Tempo & Pitch Controls + Video Surface Toggle**
   - Add Pitch & Tempo sliders to player settings sheet using `player.setPitch` and `player.setRate`.
   - Add Video mode toggle using `media_kit_video`.
5. **Phase 5: Listening History & Statistics Screen**
   - Add Top-Bar icons for History and Statistics.
   - Build Spotify Wrapped-style stats (listening minutes, top artists, charts).
6. **Phase 6: Listen Together (WebSocket Synchronized Listening)**
   - Build the room manager, join code screen, and playback sync engine.
