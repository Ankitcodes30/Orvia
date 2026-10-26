# Glossary

Terms used across the Orvia codebase and documentation.

| Term | Meaning |
|---|---|
| **Track** | A playable song with an ID, title, artists, optional album, duration, artwork, and optional lyrics. See `rust/src/api/plugin/models.rs`. |
| **MediaItem** | A union of `Track`, `AlbumSummary`, `ArtistSummary`, or `PlaylistSummary`. Used by plugin responses and UI lists. |
| **ArtistSummary / AlbumSummary / PlaylistSummary** | Lightweight metadata records for artists, albums, and playlists. |
| **StreamSource** | A resolved playable URL with quality, format, optional headers, and optional expiry. |
| **Section** | A home/discover section returned by a content-resolver plugin (carousel, grid, list, or news). |
| **ChartSummary / ChartItem** | Chart metadata and chart entries returned by a chart-provider plugin. |
| **Plugin** | A WebAssembly component that implements one of the plugin types. |
| **Plugin type** | One of `content-resolver`, `chart-provider`, `lyrics-provider`, `search-suggestion-provider`, or `content-importer`. |
| **Content resolver** | Plugin type that provides search, details, home sections, and stream URLs. |
| **Chart provider** | Plugin type that provides chart lists and chart details. |
| **Lyrics provider** | Plugin type that provides plain or synced lyrics. |
| **Search-suggestion provider** | Plugin type that provides search autocomplete. |
| **Content importer** | Plugin type that detects and imports external playlists/collections. |
| **`.bex`** | Orvia plugin package: a zstd-compressed tar containing `manifest.json`, `plugin.wasm`, and optional `plugin.wit`. |
| **Manifest** | `manifest.json` inside a plugin package. Describes identity, type, version, publisher, capabilities, keys, and country restrictions. |
| **Repository** | A JSON index of downloadable plugins. Users can add repository URLs. |
| **Hosted repository** | A repository URL added by the app during plugin bootstrap. |
| **Resolver** | Short for content resolver, or the act of resolving a track to a stream URL. |
| **Smart Replace** | Feature that searches available plugins for a working replacement for a dead track and can update playlists. |
| **Cross-plugin resolution** | Searching multiple installed plugins to find metadata or a playable stream. |
| **L1 / L2 cache** | Plugin response cache: L1 is in-memory, L2 is Isar-persisted. |
| **Stale-while-revalidate** | Return cached data immediately, then refresh in the background when it is stale. |
| **DAO** | Data access object. Owns database queries and DB↔domain mapping. |
| **Mapper** | Pure function that converts between database entities and domain models. |
| **Isar** | Local NoSQL database used for library, settings, history, and caches. |
| **FRB** | Flutter Rust Bridge. Generates Dart bindings for the Rust API. |
| **ServiceLocator** | Static singleton registry for application-lifetime services. |
| **Cubit / Bloc** | State-management objects from `flutter_bloc`. Cubits expose state and methods; blocs use events. |
| **View model** | State exposed to the UI. Must not contain database types. |
| **Country allowlist** | Manifest/repository field restricting a plugin to specific country codes. |
| **Scrobble** | A Last.fm play submission that meets Last.fm's timing rules. |
| **Crossfade** | Gradual volume transition between tracks. |
| **EQ** | Equalizer. Orvia provides a 10-band in-app EQ and a device passthrough mode. |
| **Legacy migration** | One-time migration from the pre-3.x database schema. |
| **Bootstrap** | App startup sequence that initializes Rust, Isar, services, plugins, and local music scanning. |

## Related documents

- [Architecture](../../ARCHITECTURE.md)
- [Plugin overview](../plugins/overview.md)
- [Manifest and packaging](../plugins/manifest-and-packaging.md)
