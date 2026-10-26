# Orvia Architecture

> Target architecture reference for all contributors. New and changed code should
> conform to these rules. Known legacy exceptions are listed in
> [Layer Boundary Rules](#2-layer-boundary-rules).

## Table of Contents

1. [Layer Model](#1-layer-model)
2. [Layer Boundary Rules](#2-layer-boundary-rules)
3. [Directory Structure](#3-directory-structure)
4. [Data Layer](#4-data-layer)
5. [State Layer](#5-state-layer)
6. [Plugin System](#6-plugin-system)
7. [Plugin Response Cache](#7-plugin-response-cache)
8. [Service Layer](#8-service-layer)
9. [Update & Changelog Flow](#9-update--changelog-flow)
10. [Localization](#10-localization)
11. [Keyboard Shortcuts](#11-keyboard-shortcuts)
12. [Dependency Injection](#12-dependency-injection)
13. [Navigation](#13-navigation)

---

## 1. Layer Model

```
┌─────────────────────────────────────────────────┐
│                Screens / Widgets                │  UI
│   lib/screens/                                  │
├─────────────────────────────────────────────────┤
│               Blocs / Cubits                    │  State
│   lib/blocs/                                    │
├─────────────────────────────────────────────────┤
│               Repositories                      │  Domain
│   lib/repository/                               │
├─────────────────────────────────────────────────┤
│         DAOs  ·  Mappers  ·  DBProvider         │  Data
│   lib/services/db/                              │
├─────────────────────────────────────────────────┤
│               Isar (GlobalDB)                   │  Storage
│   lib/services/db/global_db.dart               │
└─────────────────────────────────────────────────┘
```

Flow: UI dispatches events → Bloc/Cubit → Repository (or DAO directly) → DB.  
No layer may import from a layer above it. No layer may skip more than one step downward.

---

## 2. Layer Boundary Rules

| # | Rule |
|---|------|
| 1 | **UI must not import** `global_db.dart`, any `dao/*.dart`, Isar types, or `mappers/*.dart`. |
| 2 | **UI must not instantiate** DAOs or services. All state comes through Cubit/Bloc. |
| 3 | **Bloc/Cubit state classes must not contain DB types** (`*DB`). State is a view-model; use domain types. |
| 4 | **Cubits may hold DAO references** (received via constructor) but must expose domain models in state. |
| 5 | **DAOs own all DB↔domain mapping**. Callers always receive domain objects, never Isar entities. |
| 6 | **Mappers are pure functions** — no side effects, no dependencies. Imported only by DAOs and repositories. |
| 7 | **One DAO per entity concern.** `PlaylistDAO` = user-playlist CRUD; `LibraryDAO` = saved remote collections. |
| 8 | **All Bloc/Cubit classes live under `lib/blocs/`**. Screen-scoped cubits that do not touch DAOs may live under `lib/screens/`. |
| 9 | **Plugins (`lib/plugins/`) must not access the DB layer directly.** They communicate through repositories or cubits. |
| 10 | **Services (`lib/services/`) are application-lifetime singletons** registered in `ServiceLocator`. Screens do not instantiate services. |

**Known legacy exceptions (as of `3.0.4`):**

- `lib/screens/widgets/onboarding_overlay.dart`,
  `lib/screens/widgets/plugin_bootstrap_overlay.dart`, and
  `lib/screens/screen/player_views/lyrics_search.dart` construct `SettingsDAO`
  directly.
- `lib/screens/screen/library_views/cubit/current_playlist_cubit.dart` is a
  screen-scoped cubit that imports a DAO and mapper.

Treat these as cleanup targets, not patterns to copy.

---

## 3. Directory Structure

```
lib/
├── blocs/             # Global and feature blocs/cubits
├── core/
│   ├── adapters/      # Type conversion helpers (e.g. MediaItem ↔ Track)
│   ├── constants/     # Setting keys, route paths, sentinel values, cache keys
│   ├── di/            # Static ServiceLocator (no external DI framework)
│   ├── events/        # GlobalEventBus (AppError stream)
│   ├── models/        # Domain model classes and enums
│   └── theme/         # App theme constants
├── l10n/              # ARB source files + generated AppLocalizations
├── plugins/
│   ├── blocs/         # ChartBloc, ContentBloc, PluginBloc, import cubit
│   ├── errors/        # Plugin exception hierarchy
│   ├── models/        # ChartItem, Section, repository models
│   ├── services/      # PluginRepositoryService
│   ├── utils/         # Media IDs, sanitizers, plugin constants
│   └── screens/       # PluginManagerScreen
├── repository/        # Repositories orchestrating DAOs + API clients
├── routes/            # GoRouter config + route path constants
├── screens/
│   ├── screen/        # Full-page screens and screen-scoped cubits
│   └── widgets/       # Reusable widgets
├── services/
│   ├── cache/         # PluginCacheStore, PluginCacheRepository, PluginCacheWriter
│   ├── catalogue/     # Curated content surfaces
│   ├── db/
│   │   ├── dao/       # All DAO classes
│   │   ├── legacy/    # Legacy schema + migration
│   │   ├── mappers/   # Pure DB↔domain mapper functions
│   │   ├── db_provider.dart
│   │   └── global_db.dart
│   ├── discovery/     # Discovery context
│   ├── download/      # Rust-backed download service
│   ├── festival/      # Festival content service
│   ├── meta_resolver/ # Cross-plugin and smart replacement resolvers
│   ├── player/        # Player engine, queue, resolver, error handling
│   ├── plugin/        # Plugin lifecycle, event bus, storage
│   └── *.dart         # Bootstrap, local music, backup, updater, integrations
├── src/rust/          # FRB-generated Dart bindings (do not edit)
└── utils/             # Shared helpers (country, URLs, images, ticker)

rust/
├── src/api/
│   ├── bridge.rs      # FRB bridge entry points
│   ├── downloader/    # Download manager
│   ├── local_music.rs # Local music helpers
│   └── plugin/        # Manifest, loader, runtime, adapters, storage
└── src/utils/         # Rust helpers

test/                  # Flutter unit/regression tests
test_driver/           # Integration-test driver stub
fastlane/              # Store metadata
ghpage/                # GitHub Pages site (Svelte)
```

The repository root also contains `rust_builder/` (Cargokit glue), `assets/`, and
platform folders. `lib/services/db/global_db.dart` defines the Isar collections;
`lib/services/db/db_provider.dart` owns the database lifecycle.

---

## 4. Data Layer

### DBProvider

- **Location**: `lib/services/db/db_provider.dart`
- Owns the Isar instance lifecycle, DB path, maintenance, backup/restore.
- Access: `await DBProvider.db` → `Isar`.
- Initialised once in `bootstrap.dart` via `await DBProvider.init()`.

### DAOs

| DAO | Responsibility |
|-----|----------------|
| `PlaylistDAO` | User-playlist CRUD, track add/remove/order, likes, search |
| `LibraryDAO` | Save/remove/query remote collections (artists, albums, remote playlists) |
| `TrackDAO` | Track upsert, lookup, search, orphan-purge |
| `HistoryDAO` | Playback history record/query/purge |
| `SettingsDAO` | Bool and String app settings with reactive watchers |
| `CacheDAO` | Link cache and plugin response cache persistence |
| `SearchHistoryDAO` | Search history with entry-count limit |
| `DownloadDAO` | Download job tracking |
| `NotificationDAO` | Notification persistence |
| `LyricsDAO` | Lyrics cache keyed by media ID |
| `PluginStorageDAO` | Per-plugin key-value persistent storage |

**Constructor pattern** — `const` constructors accept `Future<Isar>`:

```dart
PlaylistDAO(DBProvider.db, TrackDAO(DBProvider.db))
```

### Mappers

- **Location**: `lib/services/db/mappers/`
- Pure functions, no side effects. Imported **only by DAOs and repositories**.

| File | Converts |
|------|---------|
| `media_item_mapper.dart` | `Track` ↔ `TrackDB`, `ArtistSummary` ↔ `ArtistSummaryDB` |
| `playlist_mapper.dart` | `Playlist` ↔ `PlaylistDB`, `PlaylistType` ↔ `PlaylistTypeDB` |
| `collection_mapper.dart` | `ArtistSummary`/`AlbumSummary`/`PlaylistSummary` ↔ `PlaylistDB` |
| `lyrics_mapper.dart` | `Lyrics` ↔ `LyricsDB` |

---

## 5. State Layer

### Conventions

- State classes are **view-models**: only domain types, primitives, and enums — never Isar/DB types.
- States extend `Equatable` for efficient rebuild suppression.
- Cubits receive DAO/repository dependencies through constructor injection at `BlocProvider`.

### Domain enum example

```dart
// lib/core/models/media_playlist_model.dart
enum PlaylistType { userPlaylist, album, artist, remotePlaylist }

// UI display variant — cubits map DB enum → domain enum → this before emitting:
enum LibItemTypes { userPlaylist, onlPlaylist, artist, album }
```

UI never holds `PlaylistTypeDB`. All enum mapping happens inside DAO calls within cubits.

### Key global blocs

This table is not exhaustive; feature cubits also live under `lib/blocs/`,
`lib/plugins/blocs/`, and screen-scoped cubit folders.

| Bloc/Cubit | Location | Purpose |
|---|---|---|
| `OrviaPlayerCubit` | `blocs/media_player/` | Wraps `OrviaMusicPlayer`; exposes player state |
| `MiniPlayerCubit` | `blocs/mini_player/` | Playback status for the mini-player overlay |
| `LibraryItemsCubit` | `blocs/library/` | Library list with save/remove operations |
| `DownloaderCubit` | `blocs/downloader/` | Offline download queue |
| `SettingsCubit` | `blocs/settings_cubit/` | Reactive app settings |
| `GlobalEventsCubit` | `blocs/global_events/` | Update check, changelog, alert dialogs |
| `HistoryCubit` | `blocs/history/` | Playback history |
| `LocalMusicCubit` | `blocs/local_music/` | Local scan state and local library |
| `LyricsCubit` | `blocs/lyrics/` | Lyrics fetch, cache, and offset |
| `LastdotfmCubit` | `blocs/lastdotfm/` | Scrobble timing and Last.fm state |
| `ConnectivityCubit` | `blocs/internet_connectivity/` | Network availability |
| `SearchSuggestionBloc` | `blocs/search_suggestions/` | Plugin-backed autocomplete |
| `NotificationCubit` | `blocs/notification/` | In-app notifications |
| `PlayerOverlayCubit` | `blocs/player_overlay/` | Player overlay visibility and up-next panel |
| `TimerBloc` | `blocs/timer/` | Sleep timer |
| `AddToPlaylistCubit` | `blocs/add_to_playlist/` | Add-to-playlist sheet |
| `RecentlyCubit` | `blocs/explore/` | Recently played / explore state |
| `ChartBloc`, `ContentBloc`, `PluginBloc` | `plugins/blocs/` | Plugin content, charts, and manager state |
| `ImportContentCubit` | `plugins/blocs/import/` | Plugin-driven content import |
| `ShortcutIndicatorCubit` | `services/shortcut_indicator_service.dart` | Keyboard shortcut on-screen feedback |

---

## 6. Plugin System

Plugins are WebAssembly components conforming to WIT-defined interfaces and
compiled with the external `orvia_plugin_sdk`. The SDK/WIT sources are not
vendored in this repository; the generated Rust adapters under
`rust/src/api/plugin/adapters/` show the exact interfaces the runtime expects.
The Rust layer (`rust/`) bridges Flutter and the WASM runtime.

### Plugin types

| Type | Manifest `type` | WIT package | Purpose |
|---|---|---|---|
| `ContentResolver` | `content-resolver` | `component:content-resolver` | Search, details, home sections, stream URL resolution |
| `ChartProvider` | `chart-provider` | `component:chart-provider` | Chart listings and chart details |
| `LyricsProvider` | `lyrics-provider` | `component:lyrics-provider` | Plain and synced lyrics |
| `SearchSuggestionProvider` | `search-suggestion-provider` | `component:search-suggestion-provider` | Search autocomplete |
| `ContentImporter` | `content-importer` | `component:content-importer` | Detect and import external collections |

The exported functions expected by the adapters are:

- **content-resolver:** `get-track-details`, `get-album-details`,
  `more-album-tracks`, `get-artist-details`, `more-artist-albums`,
  `get-playlist-details`, `more-playlist-tracks`, `get-streams`, `search`,
  `get-radio-tracks`, `get-home-sections`, `load-more`
- **chart-provider:** `get-charts`, `get-chart-details`
- **lyrics-provider:** `get-lyrics`, `search`, `get-lyrics-by-id`
- **search-suggestion-provider:** `get-suggestions`, `get-default-suggestions`
- **content-importer:** `can-handle-url`, `get-collection-info`, `get-tracks`

Dart calls plugins through the typed `PluginRequest` / `PluginResponse` surface in
`rust/src/api/plugin/commands.rs`; prefer `handle_plugin_request` over any legacy
JSON bridge path.

### Plugin lifecycle

1. **Install** — User picks a `.bex` file → `PluginManagerScreen` calls `PluginService.installPlugin(...)`.
2. **Load** — Plugin is registered with the WASM runtime; emits `PluginManagerEvent_PluginLoaded`.
3. **Use** — Blocs call `PluginService.execute(...)`; errors surface through `PluginEventBus`.
4. **Delete** — `PluginService.deletePlugin(...)` unloads, removes files, refreshes the available list, and optionally clears plugin storage in the BLoC. It does not emit `PluginManagerEvent_PluginDeleted`.

### Event buses

**`PluginEventBus.instance.events`** — `Stream<PluginManagerEvent>`:
- `GlobalEventListener` handles load/unload failures, generic plugin errors, and the install/delete success events if emitted.
- `PluginBloc` handles install/delete results directly and updates the plugin list; install/delete feedback does not depend on those events.
- Individual plugin blocs listen for resolver availability changes.

**`GlobalEventBus.instance.errors`** — `Stream<AppError>` for structural errors:
- `PluginNotLoadedError`, `MalformedMediaIdError`, `PluginErrorEvent`, `NetworkFailureError`
- Handled by `GlobalEventListener._onAppError()` → rate-limited snackbar.

### Plugin storage

`PluginStorageDAO` provides per-plugin KV persistence. API keys entered in `PluginManagerScreen` are stored here and injected into the plugin runtime at load time.

---

## 7. Plugin Response Cache

Two-tier cache (L1 in-memory + L2 Isar) for expensive network calls made through WASM plugins.

```
 Bloc
  │
  ▼
 PluginCacheRepository
  ├─ L1: PluginCacheStore (typed in-memory LRU)
  │       chart_details · chart_list · home_sections
  └─ L2: CacheDAO + Isar (JSON blobs, survives restart)
              ▲ promoted on L2 hit
              debounced batch writes via PluginCacheWriter
```

**Read path**: L1 hit → return instantly. L1 miss → L2 lookup (decoded in isolate via `compute`) → promote to L1 → return `(value, isStale)`.

**Write path**: Insert into L1 immediately, queue for debounced batch L2 write. Flushed on app pause and low-memory lifecycle events.

**Stale-while-revalidate**: Blocs emit cached data immediately then refresh in the background when `isStale`. `ChartBloc` uses an 8-hour staleness threshold; `ContentBloc` uses 2 hours. `ForceRefresh*` events bypass the cache entirely.

**Cache keys**: `chart_list::<pluginId>`, `chart_cache::<pluginId>::<chartId>`, `home_sections::<pluginId>`.

**Location**: `lib/services/cache/`

---

## 8. Service Layer

Application-lifetime services are exposed through the static `ServiceLocator`.
Stateless helpers and per-screen services may be constructed directly; screens
must not construct DAOs.

| Service | Purpose |
|---|---|
| `OrviaMusicPlayer` | Core audio handler wrapping `audio_service` and `media_kit`; owns queue and playback |
| `PlayerEngine` | Playback engine, equalizer, crossfade, volume, and stream handling |
| `QueueManager` | Queue ordering, shuffle, repeat, and current-track state |
| `MediaResolverService` | Resolves tracks to playable streams through plugins |
| `PlayerErrorHandler` | Player failure recovery and user-facing error mapping |
| `RelatedSongsManager` | Related-song suggestions and auto-play |
| `RecentlyPlayedTracker` | Recently played history updates |
| `PluginService` | Single Dart entry point to the Rust WASM plugin runtime |
| `PluginRepositoryService` | Fetch, save, and sync plugin repository manifests |
| `PluginBootstrapService` | First-run hosted repository setup and reconciliation |
| `PluginCacheRepository` | Plugin response cache (L1 + L2) |
| `PluginEventBus` / `GlobalEventBus` | Plugin lifecycle events and structural error events |
| `RustDownloadService` | Rust download manager bridge (pause/resume/cancel/restore) |
| `LocalMusicService` | Android MediaStore and desktop folder scanning |
| `ImportExportService` | JSON/M3U import and export |
| `StorageBackupService` | Isar snapshots, legacy JSON backups, restore validation |
| `CrossPluginResolver` | Cross-plugin metadata and stream lookup |
| `SmartTrackReplacementService` | Finds and applies replacements for dead tracks |
| `SharedUrlResolverService` | Resolves supported shared URLs into content |
| `SongMetadataRefreshService` | Refreshes stale track metadata through plugins |
| `DiscordService` | Desktop Discord Rich Presence |
| `OnboardingService` | First-run onboarding state |
| `OrviaUpdaterTools` | GitHub/SourceForge update checks and changelog fetch |
| `Catalogue`, `Discovery`, `Festival` services | Curated and contextual content surfaces |

**Built-in curated content:** `BestOf2026Service`, `CreatorsChoiceService`,
`FestivalService`, and the featured-artist/Navratri widgets contain hard-coded
JioSaavn IDs and image URLs. They are curated discovery surfaces, not a
general-purpose source integration, and playback depends on the default JioSaavn
content-resolver plugin (`content-resolver.bloomfactory.jisaavn`). New providers
should be plugins rather than additions to these lists.

---

## 9. Update & Changelog Flow

```
App start
  └─ GlobalEventsCubit.checkForUpdates()
       └─ getAppUpdates()          (services/orvia_updater_tools.dart)
            ├─ GitHub Releases API
            └─ SourceForge fallback

            Result map keys:
              results   → bool: new version available
              newVer    → String: latest version name
              newBuild  → String: latest build number
              changelogs → String?: text if unread changelog exists
                  │
                  ├─ changelogs != null
                  │     → emit WhatIsNewState(changeLogs)
                  │     → GlobalEventListener: push ChangelogScreen(showOlderVersions: false)
                  │     → ChangelogScreen on first frame:
                  │           SettingsCubit.putSettingStr(SettingKeys.readChangelogs, label)
                  │
                  └─ results == true  &&  autoUpdateNotify setting == true
                        → emit UpdateAvailable(newVersion, newBuild, downloadUrl)
                        → GlobalEventListener: showOrviaDialog with localised strings
                             ├─ "Later" → dismiss
                             └─ "Update Now" → launchUrl(downloadUrl)
```

**Current endpoint caveat**: `lib/services/orvia_updater_tools.dart` still
queries the legacy `HemantKArya/Orvia` GitHub repository and the SourceForge
project. The SourceForge project and the legacy changelog URL are currently
unreachable. Re-verify or update those endpoints before relying on in-app update
checks; see [the feature catalog](docs/product/features.md).

**Changelog gate**: `changelogs` is populated only when the installed version equals the latest version (i.e. the user is up-to-date but hasn't seen the changelog) or on a fresh install that matches the latest release. The `readChangelogs` setting key prevents re-display on subsequent launches.

**`UpdateAvailable` state** carries `newVersion` and `newBuild` — no pre-formatted message string. The listener calls `l10n.updateAvailableBody(ver, build)` so the text is properly localised.

---

## 10. Localization

- **Format**: Flutter ARB, configured in `l10n.yaml`.
- **Template**: `lib/l10n/app_en.arb`.
- **Locales**: `en`, `hi`, `de`, `es`, `ja`, `ko`, `zh`.
- **Generated files**: `lib/l10n/app_localizations*.dart` — do not edit manually.
- **Regenerate**: `flutter gen-l10n`
- **Access in widgets**: `AppLocalizations.of(context)!`
- **Language labels**: `lib/l10n/language_options.dart` maps locale codes to display names.

See [docs/development/localization.md](docs/development/localization.md) for the
add-a-language workflow and key conventions.

### Key naming conventions

| Prefix | Usage |
|--------|-------|
| `tooltip*` | `Tooltip.message` values |
| `snackbar*` | `SnackbarService.showMessage()` arguments |
| `button*` | Dialog/sheet action labels |
| `dialog*` | Dialog title or body strings |
| `player*` | Player-screen strings |
| `plugin*` | Plugin system user-visible messages |

**Rule**: All user-visible hardcoded strings must use `AppLocalizations`. Cubits and services that lack `BuildContext` must pass raw data (version numbers, IDs, names) to the UI layer so it can format user-facing text.

---

## 11. Keyboard Shortcuts

`KeyboardShortcutsHandler` is a `StatefulWidget` wrapping the app root. Its
`State` registers a `HardwareKeyboard` global handler. It is enabled on Windows,
Linux, macOS, and Android with a hardware keyboard. Shortcuts are ignored while a
text input is focused and while the player overlay is hidden (media keys are
still handled).

| Key | Action |
|-----|--------|
| Space | Play / Pause |
| → / ← | Next / Previous track |
| Alt+→ / Alt+← | Seek +5 s / −5 s |
| ↑ / ↓ | Volume +5 % / −5 % |
| M | Mute / unmute |
| L | Toggle like |
| S | Toggle shuffle |
| R | Cycle loop mode (Off → All → One) |
| T | Open sleep timer |
| Esc / Backspace | Collapse up-next panel or close player |

Media keys (play/pause, next, previous, stop) are handled when available.

`ShortcutIndicatorCubit` drives transient on-screen feedback overlays rendered by `ShortcutsIndicatorWidget`.

---

## 12. Dependency Injection

Constructor injection through the `BlocProvider` tree in `main.dart`. The static
`ServiceLocator` in `lib/core/di/service_locator.dart` holds application-lifetime
services; there is no external DI framework.

```dart
// BlocProvider pattern (main.dart)
BlocProvider(
  create: (_) => LibraryItemsCubit(
    playlistDao: PlaylistDAO(DBProvider.db, TrackDAO(DBProvider.db)),
    libraryDao: LibraryDAO(DBProvider.db),
  ),
),

// ServiceLocator pattern (core/di/service_locator.dart)
ServiceLocator.pluginCache             // PluginCacheRepository
ServiceLocator.pluginService           // PluginService
ServiceLocator.pluginRepositoryService // PluginRepositoryService
```

`ServiceLocator.setup()` is idempotent and is called once from
`bootstrapApp()` before `runApp`.

---

## 13. Navigation

- **Router**: GoRouter, configured in `lib/routes/app_router.dart`.
- **Route names and paths**: `lib/core/constants/route_paths.dart`.
- **Other constants**: `lib/core/constants/setting_keys.dart`, `cache_keys.dart`, and `sentinel_values.dart`.
- **Deep links**: handled by GoRouter redirect logic.
- **Navigator keys**: `AppRouter.globalRouterKey` and `AppRouter.exploreNavigatorKey` are used for out-of-tree navigation (update dialogs, changelog screen pushed from within a cubit listener).

