# User Guide

This guide covers installing Orvia, completing first-run setup, and using the
main features. It is written for the current `3.x` release line.

## Install Orvia

Use the download links in the root [README](../../README.md#download-and-install).
GitHub Releases is the current official distribution channel. The SourceForge
and IzzyOnDroid listings previously referenced by the project are not currently
reachable and should not be used until they are re-verified.

Only the official pages listed in the README are maintained by the project.
Third-party APKs or repackaged installers may contain malware.

## First run

On first launch Orvia may show:

1. **Onboarding** — a short introduction to the app.
2. **Language and country** — used for the interface and country-aware plugins.
3. **Plugin repository bootstrap** — adds the hosted plugin repositories and may
   offer install-on-bootstrap plugins.

If setup is skipped or fails, open the plugin manager. When the repository list
is empty, use **Sync official repositories**; otherwise add a repository URL
manually. The bootstrap state is stored in the app database, so it does not
repeat on every launch.

## Plugins

Orvia does not bundle a general-purpose music source. A **content-resolver
plugin** is required for remote search, home sections, charts, and stream URLs.
Some curated JioSaavn discovery surfaces also require the JioSaavn
content-resolver plugin for playback.

### Install a plugin

1. Open the plugin manager.
2. Choose **Install from file** and select a `.bex` package.
3. Review the plugin name, type, version, publisher, and requested keys.
4. Confirm installation.
5. If the plugin requires an API key, enter it when prompted.

### Add a plugin repository

1. Open the plugin manager.
2. Add a repository URL that returns a JSON repository manifest.
3. Refresh the repository list.
4. Install the plugins you want.

Repositories are synced when the app opens or resumes, at most once every 30
minutes, and installed plugins can update automatically. A plugin that is
currently loaded cannot be replaced until it is unloaded.

### Plugin priorities

When multiple plugins provide the same capability, Orvia can use a preferred
resolver or lyrics provider. Set priorities in the plugin settings if you want a
specific source to win.

### Remove a plugin

Unload the plugin first if it is active, then delete it from the plugin manager.
Deleting a plugin removes its installed files. You can choose whether to also
remove its saved keys and local plugin storage.

## Local music

- **Android:** grant audio/media permission. Orvia uses MediaStore to discover
  device music.
- **Windows, Linux, macOS:** choose music folders; Orvia scans them for local
  files.
- Automatic scanning can be disabled in settings.

Local tracks appear in the local music view and can be mixed with remote tracks
in playlists and the queue.

## Playback

The player supports:

- Queue management and reordering.
- Shuffle and repeat modes.
- Seek and volume controls.
- Crossfade with a configurable duration (`0` disables it).
- A 10-band equalizer. Use **device** mode to bypass the in-app EQ and let a
  system equalizer process the audio.
- A sleep timer.
- Native media controls where the platform supports them.

If a remote track becomes unavailable, Smart Replace can look for a working
replacement through your installed plugins.

## Lyrics

Lyrics are supplied by lyrics-provider plugins. When lyrics are available:

- Open the lyrics view from the player.
- Use the offset control if the timing drifts.
- Use the full-screen lyrics view for a karaoke-style display.

If no lyrics appear, check that a lyrics provider is installed and enabled, and
that the track has enough metadata for a match.

## Library

The library stores playlists, liked tracks, imported collections, and history.

- Create and edit playlists.
- Pin or reorder playlists.
- Like or unlike tracks.
- Search within library items.
- Import or export playlists/tracks as JSON or M3U.
- Use plugin content importers for supported external collections.

## Downloads and offline playback

Downloads are managed by the Rust download manager and can be paused, resumed,
or cancelled. Downloaded tracks are available offline and are grouped in the
downloads playlist.

Download location and quality are configurable in settings.

## Backup and restore

Orvia supports three restore paths:

| Format | Use |
|---|---|
| Isar snapshot (`.isar`, `.db`) | Full app database backup from a compatible version. |
| Legacy full JSON | Older full-backup format; can restore media items. |
| Playlist/track JSON | Import a playlist or track export. |

A backup from an older app version with an incompatible database schema may need
to be exported as JSON from that version and imported here instead.

## Integrations

### Last.fm

Add your Last.fm credentials in settings to enable scrobbling. Tracks must meet
Last.fm's scrobble rules; plays are cached locally for retry when the network is
unavailable.

### Discord Rich Presence

Discord Rich Presence is available on Windows, Linux, and macOS. It shows the
current track and playback state on your Discord profile when Discord is running.

## Keyboard shortcuts

Shortcuts are handled globally when the player overlay is visible. They are
desktop-focused and also work on Android with a hardware keyboard.

| Key | Action |
|---|---|
| `Space` | Play / pause |
| `Right` / `Left` | Next / previous track |
| `Alt` + `Right` / `Left` | Seek forward / backward 5 seconds |
| `Up` / `Down` | Volume up / down 5% |
| `M` | Mute / unmute |
| `L` | Like / unlike the current track |
| `S` | Toggle shuffle |
| `R` | Cycle repeat mode (off → all → one) |
| `T` | Open the sleep timer |
| `Esc` / `Backspace` | Collapse the up-next panel or close the player |

Media keys (play/pause, next, previous, stop) are handled when available.

## Data and privacy

Orvia stores library data, settings, caches, and plugin storage on the device
using Isar. The app does not require an Orvia account. Network requests are made
by plugins, update checks, and optional integrations such as Last.fm and Discord.

Use **Reset app data** only when you intend to remove the local database and
start over. Create a backup first.

## Troubleshooting

| Problem | Try |
|---|---|
| No remote music or empty home screen | Install a content-resolver plugin and refresh its repository. |
| Playback fails for a track | Try another source/plugin, refresh metadata, or use Smart Replace. |
| Local music is missing | Check media permission (Android) or add the correct folders (desktop). |
| Lyrics are missing | Install a lyrics-provider plugin and verify track metadata. |
| Plugin will not update | Unload the plugin first; then retry the update. |
| Update check fails | Check network access; the app tries GitHub then SourceForge. If both fail, download the latest release from GitHub. |
| App data is corrupted | Restore a compatible backup or reset app data. |

## Getting help

- Search existing issues in the repository.
- Open a bug report with the app version, platform, steps to reproduce, and logs.
- Report security issues privately using [SECURITY.md](../../SECURITY.md).
- For contribution questions, see [CONTRIBUTING.md](../../CONTRIBUTING.md).
