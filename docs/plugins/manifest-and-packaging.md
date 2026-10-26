# Manifest and Packaging

A plugin package (`.bex`) is a zstd-compressed tar archive containing a manifest,
a WebAssembly component, and optionally its WIT file.

## Manifest schema

`manifest.json` is validated by `rust/src/api/plugin/manifest.rs`.

| Field | Required | Notes |
|---|---|---|
| `manifest_version` | Yes | Must resolve to `1`. Numbers and integer-like strings such as `"1"` or `"1.0"` are accepted; the installer compares the resolved value. |
| `id` | Yes | Non-empty. Also used as the install directory name, so use a filesystem-safe ID. |
| `name` | Yes | Human-readable display name. |
| `version` | Yes | Integer string (`"1"`, `"2"`, `"42"`). Semver is rejected. |
| `type` | Yes | `content-resolver`, `chart-provider`, `lyrics-provider`, `search-suggestion-provider`, or `content-importer`. |
| `description` | Yes | Non-empty. |
| `publisher.name` | Yes | Non-empty. |
| `publisher.url` | No | Publisher website. |
| `publisher.contact` | No | Contact string. |
| `publisher.key_id` | No | Metadata only; see [Security](#security). |
| `license` | No | License identifier or text. |
| `homepage` | No | Must start with `http://` or `https://` when provided. |
| `icon` | No | Icon reference; must be non-empty when provided. |
| `host_site` | No | Array of HTTP(S) URLs. |
| `capabilities` | No | Array of capability strings; entries must be non-empty. |
| `created_at` | No | ISO 8601 timestamp string. |
| `remote_url` | No | Optional remote metadata URL. |
| `keys_required` | No | Map of key name to `{description, default, is_secret}`. |
| `thumbnail_url` | No | Display thumbnail. |
| `resolver` | No | Boolean hint; defaults to `false`. |
| `last_updated` | No | ISO 8601 timestamp string. |
| `country_allowlist` | No | Uppercase ISO country codes. Empty means unrestricted. |

Unknown fields are ignored by the current deserializer; do not rely on them as a
contract.

## Example manifest

```json
{
  "manifest_version": 1,
  "id": "content-resolver.example.music",
  "name": "Example Music",
  "version": "3",
  "type": "content-resolver",
  "description": "Example content resolver for Orvia.",
  "publisher": {
    "name": "Example Publisher",
    "url": "https://example.com",
    "contact": "plugins@example.com",
    "key_id": "example-key"
  },
  "license": "MIT",
  "homepage": "https://example.com/plugins/example-music",
  "icon": "https://example.com/icon.png",
  "host_site": ["https://api.example.com"],
  "capabilities": ["search", "streaming"],
  "created_at": "2026-01-01T00:00:00Z",
  "remote_url": "https://example.com/plugins/example-music.json",
  "keys_required": {
    "api_key": {
      "description": "API key for authenticating",
      "default": null,
      "is_secret": true
    }
  },
  "thumbnail_url": "https://example.com/thumbnail.png",
  "resolver": true,
  "last_updated": "2026-01-02T00:00:00Z",
  "country_allowlist": ["US", "IN"]
}
```

## Version rules

- Plugin `version` is an unsigned integer string. `1.2.3` and `1.2` are invalid.
- Install compares new and existing integer versions:
  - newer → `Updated`
  - equal → `AlreadyInstalled`
  - older → `Downgraded`
- If the existing manifest cannot be parsed, the installer replaces it and
  reports `Installed`.
- `manifest_version` is separate from plugin `version`; it describes the manifest
  schema.

## Package layout

A functional package must place these files at the archive root:

```text
manifest.json
plugin.wasm
plugin.wit        # optional
```

The installer copies only these three files. Any other files in the archive are
ignored, and an enclosing directory will prevent manifest discovery.

Create a package:

```bash
tar -cf plugin.tar manifest.json plugin.wasm plugin.wit
zstd -19 plugin.tar -o plugin.bex
rm plugin.tar
```

For a plugin without WIT:

```bash
tar -cf plugin.tar manifest.json plugin.wasm
zstd -19 plugin.tar -o plugin.bex
rm plugin.tar
```

Verify the result:

```bash
file plugin.bex
tar --zstd -tf plugin.bex
```

If your `tar` lacks `--zstd`, use `zstd -dc plugin.bex | tar -tf -`.

Expected output:

```text
plugin.bex: Zstandard compressed data
manifest.json
plugin.wasm
plugin.wit
```

## Install behavior

1. The `.bex` extension is checked.
2. The archive is unpacked to a temporary directory.
3. `manifest.json` is parsed and validated.
4. `manifest_version` must resolve to `1`.
5. The country allowlist is enforced when non-empty.
6. A loaded plugin with the same ID and type blocks replacement.
7. The existing install directory is removed, then the three files are copied
   into `{appSupport}/plugins/<id>/`.
8. The plugin is loaded when `shouldLoad` is true.

If installation fails after the old directory is removed, the old plugin is not
restored. Keep a copy of the previous `.bex` when testing updates.

## Repository format

A plugin repository is a JSON document that may contain a `plugins` array:

```json
{
  "schema_version": "1",
  "name": "Example Plugins",
  "description": "Plugins maintained by Example Publisher.",
  "thumbnail_url": "https://example.com/repository.png",
  "generated_at": "2026-01-02T00:00:00Z",
  "plugins": [
    {
      "asset_name": "example-music.bex",
      "description": "Example content resolver for Orvia.",
      "id": "content-resolver.example.music",
      "name": "Example Music",
      "manifest_version": "1.0",
      "type": "content-resolver",
      "version": "3",
      "download_url": "https://example.com/plugins/example-music.bex",
      "thumbnail_url": "https://example.com/thumbnail.png",
      "publisher": {
        "name": "Example Publisher"
      },
      "country_allowlist": ["US", "IN"],
      "last_updated": "2026-01-02T00:00:00Z"
    }
  ]
}
```

Fields:

| Field | Notes |
|---|---|
| `schema_version` | Parsed but not currently enforced. |
| `name`, `description` | Repository display metadata. |
| `thumbnail_url` | Optional repository image. |
| `generated_at` | Optional ISO 8601 timestamp. |
| `plugins[].asset_name` | Filename used for the temporary download. |
| `plugins[].download_url` | Absolute URL to the `.bex`; use HTTPS. |
| `plugins[].publisher.name` | Displayed publisher name. |
| `plugins[].country_allowlist` | Normalized by the app; use uppercase ISO codes. |
| `plugins[].last_updated` | Optional ISO 8601 timestamp. |

Unknown fields are ignored. The repository service rejects HTML responses and
requires the top-level JSON to be an object. A missing `plugins` array is treated
as an empty repository.

## Catalogue format

Orvia can bootstrap from a catalogue that lists repositories:

```json
{
  "repositories": [
    {
      "id": 1,
      "name": "Example Plugins",
      "url": "https://example.com/plugins.json",
      "install": true
    }
  ]
}
```

The app tries its configured catalogue URLs in order and uses the first response
with a non-empty `repositories` list. Repositories with `install: true` are
fetched and their plugins are installed during setup. The URLs are defined in
`lib/services/plugin_bootstrap_service.dart`:

- `https://hemantkarya.github.io/Orvia/repositories.json` (legacy candidate;
  currently returns 404)
- `https://hemantkarya.github.io/BloomeeTunes/repositories.json` (active fallback
  catalogue)

Hosted discovery is best-effort; users can always add repository URLs manually.

## Publishing checklist

- [ ] Manifest validates locally.
- [ ] `version` is a new integer greater than the published version.
- [ ] `manifest_version` resolves to `1`.
- [ ] `country_allowlist` uses uppercase ISO codes.
- [ ] `.bex` contains the three expected files at the archive root.
- [ ] Install, load, use, unload, and delete were tested from a clean install.
- [ ] Upgrade from the previous version was tested.
- [ ] `download_url` is reachable over HTTPS.
- [ ] Repository JSON is valid and contains the new version.
- [ ] Thumbnail and publisher metadata are correct.

## Security

- The installer does **not** verify a signature, checksum, or publisher key.
  `publisher.key_id` is metadata, not proof of identity.
- HTTPS protects transport only; repository trust is the real boundary.
- `schema_version` is informational and not enforced.
- The manifest validator checks that `id` is non-empty but does not sanitize path
  separators. Use a safe ID and only install from trusted repositories.
- Review plugin permissions and network destinations before installing.

## Pre-install manifest check

Before installing, the Dart service calls the Rust inspector
(`inspectPackedPlugin`) to unpack the archive in a temporary directory and
validate `manifest.json`, then uses the result to enforce `country_allowlist`
early (`lib/services/plugin/plugin_service.dart`). The Rust installer unpacks and
validates the archive again before copying files
(`rust/src/api/plugin/plugin_unpacker.rs`). Both paths expect the package files
at the archive root.

## Related documents

- [Plugin overview](overview.md)
- [Plugin authoring](authoring.md)
- [Security policy](../../SECURITY.md)
