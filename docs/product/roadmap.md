# Roadmap and Planning

## How planning works

Orvia is a volunteer, experimental open-source project. There is no guaranteed
release schedule. Work is prioritized through:

1. Bug reports and regressions that block playback or data safety.
2. Platform stability and release readiness.
3. Plugin ecosystem quality and authoring experience.
4. Local music, library, and offline improvements.
5. Localization, accessibility, and documentation.

Use the repository's issues and project boards for the current, authoritative
list. This page describes direction, not commitments.

## Current focus areas

| Area | What “better” looks like |
|---|---|
| **Playback reliability** | Fewer dead states, stronger recovery, predictable queue behavior, and stable crossfade/resume flows. |
| **Plugin ecosystem** | Clear authoring docs, predictable manifest/update behavior, better repository and install UX, and safer plugin distribution. |
| **Local music** | Reliable discovery, scanning, metadata, and parity between local and remote library flows. |
| **Downloads and offline** | Robust pause/resume/cancel, clear task state, and predictable storage behavior. |
| **Library and data** | Safe migrations, reliable backup/restore, and clear import/export formats. |
| **Localization** | Complete, consistent translations and a low-friction contribution path. |
| **Documentation** | A new contributor can set up, build, test, and ship a change from the docs alone. |

## Product principles

- No ads and no forced Orvia account.
- Local-first data; the app should remain useful without a network.
- Plugin-first sources; avoid hard-coding new providers into the app. The
  existing curated JioSaavn discovery layer is a legacy exception.
- Keep the Rust boundary explicit and documented.
- Prefer small, reviewable changes over large rewrites.
- Do not promise platform or feature support that is not in the release process.

## Non-goals for now

These are not current priorities unless a maintainer explicitly adopts them:

- A hosted Orvia account or cloud library service.
- A bundled proprietary music catalog beyond the small curated JioSaavn
  discovery layer.
- A standalone recommendation model inside the app.
- Official iOS, macOS, or web releases without a maintained build/release path.
- Plugin signing or publisher-verification guarantees that are not implemented.

## How to propose work

1. Search existing issues and discussions.
2. Open an issue describing the problem, the user impact, and a proposed approach.
3. Wait for maintainer feedback before starting a large change.
4. For small fixes, a focused PR is usually fine.
5. Reference the issue in the PR and include verification steps.

## Good first contributions

- Fix a documentation gap or broken link.
- Improve an existing translation or add missing keys.
- Add a regression test for a bug you can reproduce.
- Improve error messages or empty states.
- Test the app on a platform or device that is underrepresented.
- Package or document a plugin manifest/repository.

## Related documents

- [Contributing](../../CONTRIBUTING.md)
- [Feature catalog](features.md)
- [Getting started](../development/getting-started.md)
- [Plugin authoring](../plugins/authoring.md)
