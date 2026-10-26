# Orvia Documentation

This directory is the entry point for Orvia's product, contributor, plugin, and
release documentation. The root [README](../README.md) is the short landing page;
this directory contains the details.

> Documentation baseline: Orvia `3.0.4` (`pubspec.yaml`). Commands and paths are
> verified against the repository at the time of writing. If a document disagrees
> with the code, the code is the source of truth — please open an issue or PR.

## Start here

| I want to... | Read |
|---|---|
| Understand what Orvia is and who it is for | [Product overview](product/overview.md) |
| See what the app can do today | [Feature catalog](product/features.md) |
| Install and use Orvia | [User guide](product/user-guide.md) |
| Get answers to common questions | [FAQ](product/faq.md) |
| Know what the project is working toward | [Roadmap](product/roadmap.md) |
| Set up the project and run it locally | [Getting started](development/getting-started.md) |
| Build platform artifacts | [Build and run](development/build-and-run.md) |
| Run checks and tests | [Testing](development/testing.md) |
| Follow code conventions | [Code style](development/code-style.md) |
| Add or update translations | [Localization](development/localization.md) |
| Understand domain terms | [Glossary](development/glossary.md) |
| Understand the internals | [Architecture](../ARCHITECTURE.md) |
| Build or package a plugin | [Plugin overview](plugins/overview.md), [Authoring](plugins/authoring.md), [Manifest and packaging](plugins/manifest-and-packaging.md) |
| Cut a release or deploy the website | [Release process](operations/release.md) |
| Report a vulnerability | [Security policy](../SECURITY.md) |
| Contribute code or docs | [Contributing](../CONTRIBUTING.md) |

## Documentation map

```text
docs/
├── README.md                  # This page
├── product/                   # Product and user-facing documentation
│   ├── overview.md
│   ├── features.md
│   ├── user-guide.md
│   ├── faq.md
│   └── roadmap.md
├── development/               # Contributor onboarding and workflows
│   ├── getting-started.md
│   ├── build-and-run.md
│   ├── testing.md
│   ├── code-style.md
│   ├── localization.md
│   └── glossary.md
├── plugins/                   # Plugin runtime and authoring
│   ├── overview.md
│   ├── authoring.md
│   └── manifest-and-packaging.md
└── operations/                # Release and deployment
    └── release.md
```

Root-level references:

- [README.md](../README.md) — product landing page
- [ARCHITECTURE.md](../ARCHITECTURE.md) — canonical architecture reference
- [CONTRIBUTING.md](../CONTRIBUTING.md) — contribution workflow
- [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) — community expectations
- [SECURITY.md](../SECURITY.md) — vulnerability reporting
- [CHANGELOG.md](../CHANGELOG.md) — release history

## Documentation conventions

- Write for a reader who has just cloned the repository.
- Prefer short sections, tables, and copy-pasteable commands.
- Link to existing code or another document instead of duplicating details.
- Label unverified or experimental behavior explicitly.
- Keep screenshots in `assets/docs/` and reference them with relative paths.
- Update the relevant document in the same PR that changes behavior.
- Do not include secrets, API keys, signing material, or personal data.

## Maintaining these docs

When behavior changes:

1. Update the closest guide under `docs/`.
2. Update `README.md` only if the product summary, platforms, or entry points change.
3. Update `ARCHITECTURE.md` when layers, services, directories, or plugin types change.
4. Update `CHANGELOG.md` for user-visible changes.
5. Check relative links and commands before opening the PR.
