# FAQ

## Is Orvia free?

Yes. Orvia is open source under GPL-2.0. See [LICENSE](../../LICENSE).

## Does Orvia show ads?

No. The product is designed as an ad-free player. Remote content still depends
on the plugins and services you choose to install.

## Where should I download Orvia?

Only from the official links in the root [README](../../README.md#download-and-install)
or the official sites listed there. Unofficial APKs may be modified or contain
malware.

## Why do I need plugins?

Most remote sources are plugins. Plugins provide remote search, home sections,
charts, lyrics, suggestions, imports, and stream URLs. The app includes a small
curated JioSaavn discovery layer, but those tracks still need the JioSaavn
content-resolver plugin for playback. Local music works without a plugin.

## Are plugins safe?

Plugins run as WebAssembly components inside the Rust plugin runtime and cannot
access the database layer directly. That reduces risk, but it does not make an
untrusted plugin safe: a plugin can still make network requests and process the
data you give it. Install plugins from publishers and repositories you trust.

Plugin manifests include publisher metadata and an optional key ID. Do not treat
that metadata as proof of identity unless signature verification is explicitly
documented and enforced.

## Does Orvia work offline?

Yes, for local music and downloaded tracks. Remote search, charts, plugin
updates, and streaming require network access. Some plugin responses are cached
for a limited time.

## Which platforms are supported?

Android, Windows, and Linux are the current release targets. iOS, macOS, and web
platform folders exist, but they are not part of the release workflow and should
be treated as experimental. See [Product overview](overview.md#platform-support).

## Why is a track unavailable?

Remote tracks can disappear when a source changes or a stream expires. Try
another source or plugin, refresh metadata, or use Smart Replace to find a
working alternative.

## Where does Orvia store my data?

Library data, settings, caches, and plugin storage are stored locally with Isar
in the app support/documents directories. Use the backup feature before resetting
app data or changing devices.

## Can I move my library to another device?

Yes, use backup and restore. A full Isar backup requires a compatible app
version; older or incompatible backups may need the JSON export/import path.

## How do I add or improve a translation?

Translations use Flutter ARB files in `lib/l10n/`. See
[Localization](../development/localization.md). Open an issue before starting a
new language so the locale can be coordinated.

## Does Orvia support Last.fm and Discord?

Last.fm scrobbling is available when configured in settings. Discord Rich
Presence is available on Windows, Linux, and macOS. Mobile Discord presence is
not part of the current implementation.

## Why do I need to choose a country?

Country selection supports country-aware plugin distribution and charts. A
plugin can restrict itself with a `country_allowlist`.

## How do I report a bug?

Search existing issues first, then open a new issue with:

- Orvia version and build number
- Platform and OS version
- Steps to reproduce
- Expected and actual behavior
- Relevant logs or screenshots

## How do I report a security issue?

Do not open a public issue. Follow [SECURITY.md](../../SECURITY.md).

## Can I contribute without writing code?

Yes. Documentation, translations, bug reports, design feedback, plugin manifests,
and testing on different devices are all valuable. See
[CONTRIBUTING.md](../../CONTRIBUTING.md).
