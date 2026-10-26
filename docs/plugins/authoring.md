# Plugin Authoring

This guide describes the contract a plugin must implement. The SDK and WIT source
files are external to this repository; the generated adapters under
`rust/src/api/plugin/adapters/*/bindgen.rs` are the authoritative in-repo
reference for the expected interfaces.

## Before you start

1. Choose one plugin type. A package declares exactly one type.
2. Use a stable, filesystem-safe plugin `id` (no slashes or traversal).
3. Use integer plugin versions (`"1"`, `"2"`, `"42"`). Semver is not accepted by
   the manifest validator.
4. Keep network, parsing, and error handling inside the plugin; return typed
   errors instead of panicking.
5. Treat all remote data as untrusted.

## WIT contract

The runtime uses the WASM component model. Each plugin type has a WIT package and
a `utils` host interface.

| Type | WIT package | Exported functions |
|---|---|---|
| Content resolver | `component:content-resolver` | `get-track-details`, `get-album-details`, `more-album-tracks`, `get-artist-details`, `more-artist-albums`, `get-playlist-details`, `more-playlist-tracks`, `get-streams`, `search`, `get-radio-tracks`, `get-home-sections`, `load-more` |
| Chart provider | `component:chart-provider` | `get-charts`, `get-chart-details` |
| Lyrics provider | `component:lyrics-provider` | `get-lyrics`, `search`, `get-lyrics-by-id` |
| Search suggestions | `component:search-suggestion-provider` | `get-suggestions`, `get-default-suggestions` |
| Content importer | `component:content-importer` | `can-handle-url`, `get-collection-info`, `get-tracks` |

The exact function signatures and record types are defined by the WIT files used
to generate the adapters. Do not guess field names; mirror the generated
`ComponentType` definitions.

### Host utilities

Every plugin package has access to a `utils` interface:

| Function | Purpose |
|---|---|
| `http-request(url, options)` | HTTP request through the Rust host. |
| `random-number()` | Random `u64`. |
| `current-unix-timestamp()` | Current Unix timestamp in seconds. |
| `storage-set(key, value)` | Persist a per-plugin value. |
| `storage-get(key)` | Read a per-plugin value. |

`http-request` options include method, headers, body, and timeout. The host uses
a browser-like user agent, a 30-second client timeout, and caps requested
timeouts at 30 seconds. There is no direct filesystem, database, or UI access.

## Data model

Plugin responses use the shared model types in
`rust/src/api/plugin/models.rs`:

- `Track` — id, title, artists, optional album, duration, artwork, URL, explicit
  flag, optional lyrics.
- `ArtistSummary`, `AlbumSummary`, `PlaylistSummary` — lightweight metadata.
- `StreamSource` — URL, quality (`Low`/`Medium`/`High`/`Lossless`), format,
  optional headers, optional expiry.
- `Section` — home/discover section with card type and media items.
- `ChartSummary`, `ChartItem` — chart metadata and entries.
- `PagedTracks`, `PagedAlbums`, `PagedMediaItems` — paginated results with
  `next_page_token`.
- `Lyrics` — plain, synced, and copyright text attached to a track.
- `PluginLyrics` — lyrics-provider result with plain text, LRC, structured lines,
  instrumental flag, and sync type.
- `LyricsMetadata` / `TrackMetadata` — lyrics source metadata and lookup input.

IDs must be stable for the lifetime of the underlying item. The runtime stamps
plugin identity on responses before they cross the bridge; do not reuse another
plugin's IDs.

## Content resolver behavior

A content resolver should implement the parts it can support and return empty or
unsupported results for the rest. The runtime expects:

- Search with filters (`All`, `Track`, `Album`, `Artist`, `Playlist`) and optional
  pagination.
- Track, album, artist, and playlist details.
- More-tracks / more-albums pagination.
- `get-streams` returning playable `StreamSource` values.
- Home sections and load-more.
- Optional radio tracks.

`GetSegmentsForTrack` exists in the Dart command surface but is not part of the
content-resolver WIT interface; the adapter currently returns an empty segment
list.

Stream URLs should include headers when the source requires them and an expiry
when the URL is time-limited. Return multiple qualities when available; the player
selects based on settings and availability.

## Chart, lyrics, suggestion, and importer behavior

- **Chart provider:** return a stable chart list and chart entries. Chart data is
  cached with an 8-hour staleness threshold.
- **Lyrics provider:** return a `PluginLyrics` result with plain text, LRC,
  and/or structured lines, plus `sync_type` (`None`, `Line`, or `Syllable`) and
  `LyricsMetadata`. Include plain text as a fallback when timing is unavailable.
- **Search suggestions:** return suggestions for a query and default suggestions
  when the query is empty.
- **Content importer:** answer `can-handle-url`, describe the collection, and
  return its tracks. Do not import silently; the UI owns confirmation.

## API keys

Declare required keys in `manifest.json`:

```json
{
  "keys_required": {
    "api_key": {
      "description": "API key for authenticating",
      "default": null,
      "is_secret": true
    }
  }
}
```

Read the value with `storage-get("api_key")`. Do not log secrets. If a key is
missing, return a clear error instead of crashing.

## Errors and limits

- Return typed errors/result values; never panic on malformed input.
- Bound response sizes and pagination loops.
- Validate URLs before fetching them.
- Avoid unbounded retries inside a single call; let the app surface the failure.
- Do not attempt to read local files or the app database; those capabilities are
  not exposed.

## Test your plugin

1. Build the WASM component with the SDK.
2. Create `manifest.json` and package the `.bex`.
3. Inspect the manifest in the app before installing.
4. Install the plugin, load it, and exercise every command you implement. The
   app performs a pre-install manifest check for country restrictions, then Rust
   validates and installs the package.
5. Check the app logs for plugin errors and sanitized messages.
6. Test with no API key, an invalid key, an expired stream URL, and a network
   failure.
7. Test country restrictions if your manifest declares an allowlist.

Useful in-app flow:

```text
Plugin manager → Install from file → select .bex → review → install → load
```

## Checklist

- [ ] One valid plugin type.
- [ ] Stable ID and integer version.
- [ ] Manifest fields are complete and valid.
- [ ] Exported WIT functions match the adapter.
- [ ] Stream URLs include headers/expiry when needed.
- [ ] Errors are returned, not panicked.
- [ ] API keys are read from plugin storage and never logged.
- [ ] `.bex` contains `manifest.json`, `plugin.wasm`, and optional `plugin.wit`.
- [ ] Tested install, load, use, unload, and delete.

## Related documents

- [Plugin overview](overview.md)
- [Manifest and packaging](manifest-and-packaging.md)
- [Architecture](../../ARCHITECTURE.md#6-plugin-system)
