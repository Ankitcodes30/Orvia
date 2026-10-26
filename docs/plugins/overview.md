# Plugin System Overview

Orvia is primarily plugin-first: most remote music sources are not compiled into
the app. A small curated JioSaavn discovery layer is built in, but playback of
those tracks still depends on the JioSaavn content-resolver plugin. A plugin is a
WebAssembly component that implements a typed interface, is packaged as a `.bex`
file, and is loaded by the Rust runtime.

## Runtime

| Piece | Responsibility |
|---|---|
| `PluginService` (`lib/services/plugin/`) | Single Dart entry point for install, load, unload, delete, discovery, and execution. |
| `PluginManager` (`rust/src/api/plugin/plugin.rs`) | Rust-side registry of loaded plugins and runtime state. |
| `PluginEventBus` | Broadcasts Rust lifecycle and storage events to Dart. |
| `wasm_runtime_layer` + `wasmi_runtime_layer` | Default portable WASM runtime backend. |
| `waclay` | WASM component model support and WIT bindings. |
| `PluginRepositoryService` | Fetches and persists repository manifests. |
| `PluginBootstrapService` | Adds hosted repositories during first-run setup. |
| `PluginCacheRepository` | Caches expensive plugin responses in memory and Isar. |

The runtime currently uses the Wasmi interpreter. `wasmtime` is documented in
`rust/src/api/plugin/wasm_runtime.rs` as a faster alternative, but it is not the
default configuration.

## Plugin types

| Type | Manifest `type` | Responsibility |
|---|---|---|
| Content resolver | `content-resolver` | Search, details, home sections, stream resolution, radio |
| Chart provider | `chart-provider` | Chart listings and chart entries |
| Lyrics provider | `lyrics-provider` | Plain or synced lyrics |
| Search-suggestion provider | `search-suggestion-provider` | Autocomplete suggestions |
| Content importer | `content-importer` | Detect and import external collections |

A plugin declares exactly one type in `manifest.json`. The runtime registers one
adapter per type under `rust/src/api/plugin/adapters/`.

## Install and storage locations

- Plugins are installed under `{appSupport}/plugins/<pluginId>/`.
- The installer copies `manifest.json`, `plugin.wasm`, and optional `plugin.wit`.
- Plugin key/value storage is held in memory by Rust and persisted to Isar by
  `PluginStorageService`.
- Plugin response caches are stored in Isar with an in-memory L1 cache.

Deleting a plugin unloads it first, removes its directory, and refreshes the
available-plugin list. The UI can also clear the plugin's stored keys and
key/value data.

## Lifecycle

```text
Install (.bex)
  └─ Rust inspect manifest → enforce country allowlist → Rust unpack/validate
       → compare version → copy files → optionally load
       → return PluginInstallResult

Load
  └─ create component instance → register with manager → emit PluginLoaded

Use
  └─ Dart sends PluginRequest → Rust adapter → WASM export → PluginResponse

Unload
  └─ drop instance → emit PluginUnloaded

Delete
  └─ unload if needed → remove directory → refresh list
```

The runtime emits `PluginLoading`, `PluginLoaded`, `PluginLoadFailed`,
`PluginUnloading`, `PluginUnloaded`, `PluginUnloadFailed`, `PluginListRefreshed`,
`StorageSet`, `StorageDeleted`, `StorageCleared`, `ManagerInitialized`, and
`Error`. The event enum also defines install/delete events, but the current
install/delete paths return a status and refresh the list instead of emitting
those events; the Dart BLoC shows the corresponding success/error message.

## Installation statuses

| Status | Meaning |
|---|---|
| `Installed` | New plugin installed. |
| `Updated` | Installed version is newer than the existing one. |
| `Downgraded` | Installed version is older than the existing one; the installer replaces it and reports the downgrade. |
| `AlreadyInstalled` | Same version already installed. |
| `PluginLoaded` | Plugin is currently loaded; unload it before replacing. |
| `Failed` | Installation failed; check the returned error. |

## API keys and plugin storage

A manifest can declare `keys_required`:

```json
{
  "api_key": {
    "description": "API key for authenticating",
    "default": null,
    "is_secret": true
  }
}
```

The plugin manager collects these values and stores them per plugin. Plugins read
them through the `storage-get` host function. Secret values are masked in the UI,
but they are stored locally in the app database — do not treat them as
hardware-backed secrets.

## Host capabilities

Plugins do not have direct filesystem or database access. The `utils` host
interface exposes:

- `http-request` — HTTP request through the Rust host.
- `random-number` — random `u64`.
- `current-unix-timestamp` — current Unix timestamp in seconds.
- `storage-set` / `storage-get` — per-plugin key/value storage.

The HTTP helper uses a browser-like user agent and a default timeout. Plugins
should still validate and bound their own responses.

## Response cache

Expensive calls can be cached by the Dart layer:

- **L1:** typed in-memory LRU (`PluginCacheStore`).
- **L2:** Isar JSON blobs (`CacheDAO`), written through a debounced writer.
- **Stale-while-revalidate:** blocs show cached data immediately and refresh in
  the background. `ForceRefresh*` events bypass the cache.

Cache keys are namespaced by plugin and resource, for example
`chart_list::<pluginId>` and `home_sections::<pluginId>`.

## Distribution

Plugins are distributed through repository manifests. Users can add repository
URLs, and the app tries hosted catalogue URLs during setup. Repositories support:

- Plugin metadata and download URLs.
- Country allowlists.
- Version comparison and background updates.

Configured catalogue URLs, in fallback order:

- `https://hemantkarya.github.io/Orvia/repositories.json` (legacy candidate;
  currently returns 404)
- `https://hemantkarya.github.io/BloomeeTunes/repositories.json` (active fallback
  catalogue)

These URLs are defined in `lib/services/plugin_bootstrap_service.dart` and may
change between releases. Hosted discovery is best-effort; users can add
repositories manually.

## Security model

- Plugins run in a WASM sandbox and cannot access Isar or the Dart UI directly.
- Network access goes through the host HTTP function.
- Installation is restricted by `manifest_version` and optional country allowlist.
- The manifest includes publisher metadata and an optional `key_id`, but
  **manifest signing is not enforced**. Do not claim signature verification as a
  security guarantee until it is implemented and tested.
- An untrusted plugin can still make network requests and process the data you
  provide. Install from publishers and repositories you trust.

## Related documents

- [Authoring](authoring.md)
- [Manifest and packaging](manifest-and-packaging.md)
- [Architecture](../../ARCHITECTURE.md#6-plugin-system)
- [Security policy](../../SECURITY.md)
