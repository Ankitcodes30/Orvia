# Code Style

Orvia uses standard Flutter/Dart and Rust tooling. The architecture rules in
[ARCHITECTURE.md](../../ARCHITECTURE.md) are mandatory; this page covers the
day-to-day conventions.

## Dart and Flutter

- Follow `package:flutter_lints` (configured in `analysis_options.yaml`).
- Format with `dart format .`.
- Prefer `const` constructors and immutable state.
- Use `snake_case` for files, `PascalCase` for types, and `camelCase` for members.
- Keep widgets small and move reusable UI into `lib/screens/widgets/`.
- Do not add a dependency unless the project already uses it or the PR explains
  why a new dependency is necessary.

## Architecture boundaries

| Layer | Rule |
|---|---|
| UI (`lib/screens/`) | Must not import `global_db.dart`, DAOs, Isar types, or mappers. Must not instantiate DAOs/services. |
| State (`lib/blocs/`, feature cubits) | May hold DAO/repository references, but state classes expose domain types and primitives only — never `*DB` types. |
| Repositories (`lib/repository/`) | Orchestrate DAOs and API clients; return domain models. |
| DAOs (`lib/services/db/dao/`) | Own all DB↔domain mapping. Callers receive domain objects. |
| Mappers (`lib/services/db/mappers/`) | Pure functions with no side effects; imported only by DAOs/repositories. |
| Plugins (`lib/plugins/`) | Must not access the DB layer directly. Go through repositories or cubits. |
| Services (`lib/services/`) | Application-lifetime singletons wired through `ServiceLocator`; screens do not construct them. |

Use one DAO per entity concern. For example, `PlaylistDAO` handles user-playlist
CRUD, while `LibraryDAO` handles saved remote collections.

Known legacy exceptions to these boundaries are listed in
[ARCHITECTURE.md](../../ARCHITECTURE.md#2-layer-boundary-rules). Do not copy them
into new code.

## State management

- Use `flutter_bloc` cubits/blocs.
- State classes extend `Equatable` unless there is a specific reason not to.
- Emit view-model state, not database entities.
- Map database enums to domain enums inside the DAO/cubit boundary.
- Keep screen-scoped cubits under the screen only if they do not touch DAOs;
  otherwise place them under `lib/blocs/`.

## Localization

All user-visible strings must come from `AppLocalizations`. Do not hard-code
English text in widgets, dialogs, snackbars, or tooltips. See
[Localization](localization.md) for the ARB workflow.

Cubits and services without a `BuildContext` should pass raw values (names,
versions, IDs) to the UI, which formats the localized message.

## Rust

- Format with `cargo fmt --manifest-path rust/Cargo.toml`.
- Run `cargo clippy --manifest-path rust/Cargo.toml -- -D warnings` when possible.
- Keep Flutter Rust Bridge annotations on the public API types and functions.
- Prefer `Result`/`anyhow` for fallible operations; do not panic on user input or
  plugin data.
- Treat WASM input as untrusted.
- Do not edit generated bindings under `rust/src/api/plugin/adapters/*/bindgen.rs`
  or `lib/src/rust/` by hand.

## Generated files

Never edit these directly:

- `lib/l10n/app_localizations*.dart`
- `lib/services/db/**/*.g.dart`
- `lib/src/rust/**`
- `**/*.freezed.dart`
- `rust_builder/cargokit/**`

Regenerate with the commands in [Build and run](build-and-run.md).

## Commit messages

Use a short, imperative subject with a conventional prefix when it fits:

```text
feat: add playlist pinning
fix: recover from expired stream URLs
docs: document plugin manifest fields
refactor: move playlist mapping into DAO
test: cover settings normalization
chore: update dependencies
```

Keep commits focused. Avoid mixing formatting-only changes with behavior changes.

## Pull requests

- Reference the issue or describe the problem clearly.
- Explain the approach and any tradeoffs.
- Include verification steps and platform coverage.
- Update docs and tests with the change.
- Do not include secrets, signing files, local databases, or build artifacts.

## Documentation

- Update the closest guide under `docs/` when behavior changes.
- Update `ARCHITECTURE.md` when layers, services, directories, or plugin types change.
- Update `README.md` only for product-level changes.
- Keep commands copy-pasteable and relative links valid.
