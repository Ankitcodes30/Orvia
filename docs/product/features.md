# Feature Catalog

This page describes what Orvia does today and where the implementation lives.
Status reflects the repository, not a marketing promise.

| Status | Meaning |
|---|---|
| **Shipped** | Implemented and reachable in the app. |
| **Platform-dependent** | Implemented, but only on some platforms or with extra hardware/software. |
| **Experimental** | Implemented but still changing or not covered by the release workflow. |
| **Planned** | Not implemented; tracked as future work. |

## Playback and library

| Feature | Status | Notes | Code |
|---|---|---|---|
| Local music playback | Shipped | Android uses MediaStore discovery; desktop platforms use folder scanning. | `lib/services/local_music_service.dart`, `rust/src/api/local_music.rs` |
| Remote music playback | Shipped | Requires a content-resolver plugin that returns stream sources. | `lib/services/plugin/`, `rust/src/api/plugin/` |
| Unified queue | Shipped | Local and remote tracks share the same player queue. | `lib/services/player/queue_manager.dart` |
| Shuffle, repeat, seek | Shipped | Player controls and desktop shortcuts. | `lib/services/orvia_player.dart`, `lib/services/player/` |
| Crossfade | Shipped | Configurable duration; disabled at `0`. | `lib/services/player/`, settings in `SettingKeys.crossfadeDuration` |
| 10-band equalizer | Shipped | Built-in EQ with device passthrough mode. | `lib/services/player/`, `SettingKeys.eq*` |
| Sleep timer | Shipped | Accessible from the player UI and `T` shortcut. | `lib/screens/screen/home_views/timer_view.dart`, `lib/blocs/timer/` |
| Playlists | Shipped | Create, edit, reorder, pin, like, and search. | `lib/services/db/dao/playlist_dao.dart` |
| Likes and history | Shipped | Likes are stored in the library; history is recorded separately. | `playlist_dao.dart`, `history_dao.dart` |
| Search | Shipped | Local library search plus plugin-backed remote search. | `lib/screens/screen/search_screen.dart`, plugin blocs |
| Charts | Shipped | Provided by chart-provider plugins; availability depends on installed plugins. | `lib/plugins/blocs/chart/`, `rust/src/api/plugin/adapters/chart_provider/` |
| Downloads and offline playback | Shipped | Rust-backed download manager with pause/resume/cancel. | `lib/services/download/rust_download_service.dart`, `rust/src/api/downloader/` |
| Import and export | Shipped | JSON and M3U for playlists/tracks; plugin content importers handle external collections. | `lib/services/import_export_service.dart`, `lib/services/m3u_processor.dart` |
| Backup and restore | Shipped | Isar snapshots, legacy full JSON backups, and playlist/track JSON imports. | `lib/services/storage_backup_service.dart`, `lib/services/db/db_provider.dart` |
| Smart Replace | Shipped | Finds working replacements for dead tracks through available plugins. | `lib/services/meta_resolver/smart_track_replacement_service.dart` |
| Shared link handling | Shipped | Supported shared URLs are routed into import/resolve flows. | `lib/services/shared_url_resolver_service.dart`, `lib/main.dart` |

## Plugins and content

| Feature | Status | Notes | Code |
|---|---|---|---|
| `.bex` plugin installation | Shipped | Installs `manifest.json`, `plugin.wasm`, and optional `plugin.wit`. | `rust/src/api/plugin/plugin_unpacker.rs` |
| Plugin repository bootstrap | Shipped | Hosted repositories are added on first setup and reconciled at startup. | `lib/services/plugin_bootstrap_service.dart` |
| Plugin auto-update | Shipped | Repository sync compares plugin versions and updates in the background. | `lib/services/plugin_bootstrap_service.dart` |
| Plugin types | Shipped | Content resolver, chart provider, lyrics provider, search-suggestion provider, content importer. | `rust/src/api/plugin/types.rs` |
| Plugin storage and API keys | Shipped | Per-plugin key/value storage; `keys_required` entries are surfaced during setup. | `rust/src/api/plugin/manifest.rs`, `lib/services/plugin/` |
| Country-aware distribution | Shipped | `country_allowlist` restricts installation and repository entries. | `plugin_unpacker.rs`, `lib/plugins/models/plugin_repository.dart` |
| Plugin response cache | Shipped | L1 in-memory plus L2 Isar cache with stale-while-revalidate. | `lib/services/cache/` |
| Lyrics providers | Shipped | Plugins can return plain or synced lyrics. | `rust/src/api/plugin/adapters/lyrics_provider/` |
| Search suggestions | Shipped | Plugin-backed autocomplete. | `rust/src/api/plugin/adapters/search_suggestions/` |
| Content importers | Shipped | Plugins can detect and import external playlists/collections. | `rust/src/api/plugin/adapters/content_importer/` |
| Curated discovery | Shipped | Built-in JioSaavn lists and cards (Best of 2026, Creator's Choice, festival/Navratri, featured artists); playback requires the JioSaavn content-resolver plugin. | `lib/services/catalogue/`, `lib/services/festival/`, `lib/screens/widgets/indian_browse_categories.dart`, `featured_artists_section.dart`, `navratri_special_card.dart` |

## Lyrics and integrations

| Feature | Status | Notes | Code |
|---|---|---|---|
| Synced and plain lyrics | Shipped | Fetch through lyrics-provider plugins; cache locally. | `lib/services/`, `rust/src/api/plugin/adapters/lyrics_provider/` |
| Lyrics offset and full-screen view | Shipped | Manual offset adjustment and karaoke-style display. | `lib/blocs/lyrics/`, `lib/screens/screen/player_views/` |
| Last.fm scrobbling | Shipped | Scrobbles eligible tracks; uses local caching for retries. | `lib/blocs/lastdotfm/`, `lib/repository/LastFM/` |
| Discord Rich Presence | Platform-dependent | Windows, Linux, and macOS only. | `lib/services/discord_service.dart` |
| Desktop keyboard shortcuts | Platform-dependent | Enabled on Windows, Linux, macOS, and Android with a hardware keyboard. | `lib/services/keyboard_shortcuts_service.dart` |
| Native media controls | Platform-dependent | Provided by `audio_service` integrations per platform. | `lib/services/audio_service_initializer.dart` |
| Update checks and changelog | Experimental | Code tries GitHub Releases, then SourceForge. The configured endpoints are legacy and need re-verification before relying on in-app updates. | `lib/services/orvia_updater_tools.dart`, `lib/blocs/global_events/` |

## Appearance and localization

| Feature | Status | Notes | Code |
|---|---|---|---|
| Themes and adaptive UI | Shipped | Responsive layout and theme constants. | `lib/core/theme/` |
| Localization | Shipped | ARB-based; English, Hindi, German, Spanish, Japanese, Korean, and Chinese files are present. | `lib/l10n/`, `l10n.yaml` |
| Onboarding | Shipped | First-run setup and plugin repository bootstrap overlays. | `lib/services/onboarding_service.dart`, `lib/screens/widgets/` |
| Recommendations | Experimental | Related-song and discovery surfaces exist; recommendations depend on plugin/Last.fm data rather than a bundled model. | `lib/services/player/related_songs_manager.dart`, `lib/services/discovery/` |

## Not currently product guarantees

The following should not be documented as shipped until the release process and
tests confirm them:

- iOS, macOS, or web as supported release platforms.
- Background playback behavior on every Android OEM.
- A specific audio format list for local files.
- A built-in AI recommendation model.
- Plugin manifest signing or publisher identity verification.

## Related documents

- [User guide](user-guide.md)
- [Plugin overview](../plugins/overview.md)
- [Architecture](../../ARCHITECTURE.md)
- [Roadmap](roadmap.md)
