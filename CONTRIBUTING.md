# Contributing to Orvia

Thanks for helping improve Orvia. Contributions of code, documentation,
translations, testing, and design feedback are all welcome.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Before you start

1. Search existing issues and pull requests.
2. For a bug, include steps to reproduce, platform, and app version.
3. For a large feature or refactor, open an issue first and wait for feedback.
4. For small fixes and documentation changes, a focused PR is usually fine.
5. Never report security vulnerabilities in a public issue. Use
   [SECURITY.md](SECURITY.md).

Not sure where to start? See the
[good first contributions](docs/product/roadmap.md#good-first-contributions).

## Set up the project

Read [Getting started](docs/development/getting-started.md) for prerequisites and
platform notes. In short:

```bash
git clone https://github.com/Ankitcodes30/Orvia.git
cd Orvia
flutter pub get
flutter analyze --no-fatal-infos
cargo check --manifest-path rust/Cargo.toml
```

Recommended tool versions:

- Flutter `3.35.4` stable
- Dart `>=3.3.0`
- Rust stable
- JDK 17 for Android builds

## Fork and branch

Fork the repository, then create a branch from `main`:

```bash
git checkout main
git pull upstream main
git checkout -b feat/short-description
```

Use a descriptive branch name, for example:

- `feat/plugin-priority-ui`
- `fix/expired-stream-recovery`
- `docs/plugin-authoring`
- `l10n/hi-missing-keys`

The repository's CI targets `main`. Do not assume a `dev` branch exists.

## Make changes

Follow the architecture rules in [ARCHITECTURE.md](ARCHITECTURE.md) and the
conventions in [Code style](docs/development/code-style.md).

Key rules:

- UI must not import DAOs, Isar types, `global_db.dart`, or mappers.
- Cubit/bloc state must expose domain types, not `*DB` types.
- DAOs own DB↔domain mapping; mappers stay pure.
- Plugins must not access the database directly.
- All user-visible strings go through `AppLocalizations`.
- Do not edit generated files by hand.

These rules apply to new and changed code. Known legacy exceptions are listed in
[ARCHITECTURE.md](ARCHITECTURE.md#2-layer-boundary-rules); do not copy them.

Regenerate when needed:

```bash
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter_rust_bridge_codegen generate
```

## Run checks

Required baseline:

```bash
flutter analyze --no-fatal-infos
cargo check --manifest-path rust/Cargo.toml
```

Recommended:

```bash
flutter test
cargo clippy --manifest-path rust/Cargo.toml -- -D warnings
cargo test --manifest-path rust/Cargo.toml
cargo fmt --manifest-path rust/Cargo.toml -- --check
```

See [Testing](docs/development/testing.md) for test layout and current CI
coverage.

## Commit

Use a clear, imperative subject. Conventional prefixes are preferred:

```bash
git commit -m "feat: add playlist pinning"
git commit -m "fix: recover from expired stream URLs"
git commit -m "docs: document plugin manifest fields"
```

Keep commits focused. Do not commit:

- API keys, tokens, or signing material
- `android/key.properties` or keystores
- local databases or backups
- build outputs, logs, or screenshots unless the PR needs them
- generated files edited by hand instead of regenerated

## Pull request

Open a PR against `main` and include:

- A descriptive title and summary
- The problem being solved
- The approach and any tradeoffs
- The linked issue, if one exists
- Verification steps and platforms tested
- Screenshots or recordings for UI changes
- Documentation updates for behavior changes

Review the diff before submitting. Keep the PR reviewable; split unrelated
changes into separate PRs.

### PR checklist

- [ ] Branch is based on `main`.
- [ ] `flutter analyze --no-fatal-infos` passes.
- [ ] Relevant tests pass.
- [ ] Rust checks pass for Rust changes.
- [ ] Generated files are regenerated, not hand-edited.
- [ ] User-visible strings are localized.
- [ ] Docs are updated when behavior or setup changes.
- [ ] No secrets, signing files, or local data are included.

## Review and merge

Maintainers may request changes or suggest an alternative approach. Once approved,
a maintainer merges the PR. Please keep discussions respectful and on topic.

## Documentation contributions

Documentation lives in `docs/` with the root `README.md` as the landing page.

- Fix broken links, outdated commands, and stale screenshots.
- Prefer concise sections, tables, and copy-pasteable commands.
- Link to code or another doc instead of duplicating details.
- Label experimental or unverified behavior.
- Update the closest guide when behavior changes.

## Translation contributions

Translations use ARB files in `lib/l10n/`. Read
[Localization](docs/development/localization.md) before starting.

- Open an issue for a new language so the locale can be coordinated.
- Keep ARB keys and placeholder names unchanged.
- Run `flutter gen-l10n` and check the affected screens.
- Do not edit generated `app_localizations*.dart` files.

## Plugin contributions

Plugin documentation starts at [Plugin overview](docs/plugins/overview.md).

- Follow the manifest and packaging rules.
- Do not commit plugin binaries unless the repository explicitly asks for them.
- Document required API keys and country restrictions.
- Treat plugin input and network responses as untrusted.

## Bug reports

Include:

- Orvia version and build number
- Platform and OS version
- Steps to reproduce
- Expected and actual behavior
- Logs or screenshots when relevant
- Whether the issue happens with plugins disabled

## Security

Report vulnerabilities privately using [SECURITY.md](SECURITY.md). Do not include
exploit details in a public issue or PR.

## License

By contributing, you agree that your contributions are licensed under the
project's **GPL-2.0** license. See [LICENSE](LICENSE).

## Getting help

- [Documentation index](docs/README.md)
- [FAQ](docs/product/faq.md)
- [Architecture](ARCHITECTURE.md)
- Open an issue for questions that are not covered by the docs.
