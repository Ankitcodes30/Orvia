# Testing

## What CI runs today

The `CI` workflow (`.github/workflows/checkout.yml`) runs:

```bash
flutter analyze --no-fatal-infos
cargo check --manifest-path rust/Cargo.toml
```

The job names mention tests and Clippy, but those steps are not currently in the
workflow. Run the additional checks below locally when you change related code.

## Flutter checks

```bash
flutter pub get
flutter analyze --no-fatal-infos
```

Analyze the whole repository. Generated files and vendored build tools are
excluded in `analysis_options.yaml`.

## Flutter tests

Run the full test suite:

```bash
flutter test
```

Run a specific file:

```bash
flutter test test/regression_test.dart
flutter test test/legacy_migration_service_test.dart
```

The current tests focus on persistence and regression behavior:

- `test/regression_test.dart` covers DAOs, settings, cache, routing, media IDs,
  plugin error sanitization, and persistence flows.
- `test/legacy_migration_service_test.dart` covers migration from the legacy
  database schema.

The tests initialize `TestWidgetsFlutterBinding` and create temporary Isar
databases, so they do not touch your real app data.

On Windows, Isar tests may require the native Isar library (`libisar.dll`). Do
not commit that file; regenerate it from the pub cache when needed.

## Rust checks

```bash
cargo check --manifest-path rust/Cargo.toml
cargo clippy --manifest-path rust/Cargo.toml -- -D warnings
cargo test --manifest-path rust/Cargo.toml
cargo fmt --manifest-path rust/Cargo.toml -- --check
```

`cargo check` is the CI baseline. Clippy, tests, and formatting are recommended
before opening a PR that changes Rust code.

## Integration tests

`test_driver/integration_test.dart` is an integration-test driver stub. There is
no checked-in `integration_test/` suite at the moment. If you add one, document
the exact command here and add it to CI.

## What to test

Prefer tests that are deterministic and do not require the network or a real
plugin:

- DAO CRUD, ordering, and migration behavior.
- Settings defaults and normalization.
- Plugin cache read/write and stale-while-revalidate behavior.
- Media ID parsing and URL routing.
- Error mapping and sanitization.
- Pure mapper functions.

For plugin behavior, test the Dart-side orchestration with a fake plugin service
where possible. Rust plugin runtime tests belong under `rust/`.

## Before opening a PR

- [ ] `flutter analyze --no-fatal-infos` passes.
- [ ] Relevant `flutter test` files pass.
- [ ] `cargo check --manifest-path rust/Cargo.toml` passes for Rust changes.
- [ ] New behavior has a test or a clear reason it cannot be tested.
- [ ] Generated files were regenerated, not edited by hand.
- [ ] Documentation was updated if behavior changed.

## Related documents

- [Build and run](build-and-run.md)
- [Code style](code-style.md)
- [Contributing](../../CONTRIBUTING.md)
