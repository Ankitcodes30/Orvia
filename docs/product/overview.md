# Product Overview

## What is Orvia?

Orvia is an experimental, open-source music player that combines **local device
music** with **remote music mostly delivered through plugins**, plus a small
curated JioSaavn discovery layer. It is built with Flutter for the interface,
Rust for the plugin runtime and download engine, and Isar for local persistence.

The product goal is simple: give listeners one library and one player for their
own files and for streamed music, without ads or forced accounts. Most remote
sources are supplied by installable `.bex` plugins running in a WebAssembly
runtime. The app also ships a small curated JioSaavn discovery layer — Best of
2026, Creator's Choice, festival/Navratri cards, and featured artists — that
references JioSaavn IDs and images. Those surfaces are not a general-purpose
source integration and still require the JioSaavn content-resolver plugin for
playback.

## Who it is for

- People who want a single player for local files and online music.
- Listeners who want ad-free playback and control over their library.
- Contributors interested in Flutter, BLoC, Rust, WebAssembly, or local-first apps.
- Plugin authors who want to add a music source without forking the app.

## Core pillars

| Pillar | What it means |
|---|---|
| **Local + remote in one library** | Play downloaded or device music alongside plugin-backed streams. |
| **Plugin-first sources** | Content resolvers, charts, lyrics, suggestions, and importers are plugins. Built-in curated discovery is limited to JioSaavn references and still depends on the JioSaavn plugin. |
| **Rust-backed runtime** | Plugin loading, WASM execution, storage bridging, and downloads are handled by the Rust layer. |
| **Local-first data** | Library, playlists, history, settings, and caches are stored on the device with Isar. |
| **No ads, no forced account** | Playback does not depend on an Orvia account or an advertising pipeline. |
| **Open source** | The app is licensed under GPL-2.0 and developed in public. |

## Platform support

| Platform | Status | Notes |
|---|---|---|
| Android | Supported release target | Built and signed in the release workflow. Local music discovery uses Android MediaStore. |
| Windows | Supported release target | Built in the release workflow. Desktop shortcuts and Discord Rich Presence are available. |
| Linux | Supported release target | Built in the release workflow. Desktop shortcuts and Discord Rich Presence are available. |
| iOS | Platform folder exists, not a release target | Treat as experimental until a build/release path is documented. |
| macOS | Platform folder exists, not a release target | Treat as experimental. Discord RPC is implemented for desktop. |
| Web | Platform folder exists, not a release target | The plugin runtime and local features may not be available. Treat as experimental. |

The release workflow in `.github/workflows/main.yml` currently produces Android,
Windows, and Linux artifacts. Do not describe other platforms as supported until
they are added to the release process.

## How it fits together

```text
Flutter UI (screens, widgets)
        │
        ▼
Blocs / Cubits (view state)
        │
        ▼
Repositories and DAOs
        │
        ├── Isar (library, playlists, settings, cache)
        │
        └── Rust bridge (flutter_rust_bridge)
                ├── Plugin manager (WASM components, .bex installs)
                ├── Download manager
                └── Local music helpers
```

For the full layer model, boundary rules, and directory map, see
[ARCHITECTURE.md](../../ARCHITECTURE.md).

## Project status

Orvia is an experimental project. The `3.x` line moved most of the app from
tightly coupled source integrations to a plugin-first architecture, leaving the
curated JioSaavn discovery layer as a legacy exception. Expect behavior and
plugin APIs to evolve. The [CHANGELOG](../../CHANGELOG.md) is the authoritative
history of user-visible changes.

## Official links

Only these pages are maintained by the project:

- <https://github.com/Ankitcodes30/Orvia>
- <https://ankitcodes30.github.io/Orvia/>

Third-party sites may distribute modified APKs or malware. Download releases
from the official GitHub Releases page or the links listed in the root
[README](../../README.md). The SourceForge and IzzyOnDroid listings previously
referenced by the project are not currently reachable.

## License and attribution

Orvia is licensed under the **GNU General Public License v2.0 (GPL-2.0)**. See
[LICENSE](../../LICENSE).

Orvia is created and maintained by **Ankit Kumbhare**. It builds on the
open-source foundation originally created by **Hemant Karya**.

## Where to go next

- [Feature catalog](features.md)
- [User guide](user-guide.md)
- [Getting started for contributors](../development/getting-started.md)
- [Plugin overview](../plugins/overview.md)
- [Roadmap](roadmap.md)
