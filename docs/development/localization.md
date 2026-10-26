# Localization

Orvia uses Flutter's ARB-based localization. The source template is
`lib/l10n/app_en.arb`; generated Dart files live next to it.

## Configuration

`l10n.yaml`:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

Regenerate after editing any ARB file:

```bash
flutter gen-l10n
```

Do not edit `lib/l10n/app_localizations*.dart` by hand.

## Current locales

| Locale | Language | ARB file |
|---|---|---|
| `en` | English | `lib/l10n/app_en.arb` |
| `hi` | हिन्दी | `lib/l10n/app_hi.arb` |
| `de` | Deutsch | `lib/l10n/app_de.arb` |
| `es` | Español | `lib/l10n/app_es.arb` |
| `ja` | 日本語 | `lib/l10n/app_ja.arb` |
| `ko` | 한국어 | `lib/l10n/app_ko.arb` |
| `zh` | 中文 | `lib/l10n/app_zh.arb` |

Translation coverage varies by key. If you find a missing or incorrect string,
open an issue or a focused PR for that locale.

## Add a new language

1. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<code>.arb`.
2. Set `"@@locale": "<code>"`.
3. Translate every user-visible value. Keep the keys unchanged.
4. Preserve placeholders and their metadata exactly. For example:

   ```json
   "localMusicScanFailed": "Scan failed: {message}",
   "@localMusicScanFailed": {
     "placeholders": { "message": { "type": "String" } }
   }
   ```

5. Add the display label in `lib/l10n/language_options.dart`.
6. Run `flutter gen-l10n`.
7. Run `flutter analyze --no-fatal-infos` and the app.
8. Update the locale table in this document and the feature catalog if needed.

Flutter generates `supportedLocales` from the ARB files in `arb-dir`, so adding
the file is enough for the locale to appear in the app once the label is wired.

## Key naming conventions

| Prefix | Usage |
|---|---|
| `tooltip*` | `Tooltip.message` values |
| `snackbar*` | `SnackbarService.showMessage()` arguments |
| `button*` | Dialog/sheet action labels |
| `dialog*` | Dialog title or body strings |
| `player*` | Player-screen strings |
| `plugin*` | Plugin-system user-visible messages |
| `localMusic*` | Local music screens and permissions |
| `settings*` | Settings labels and descriptions |

## Rules

- Never translate ARB keys or placeholder names.
- Do not concatenate translated fragments to build sentences; add a full string
  with placeholders instead.
- Do not hard-code user-visible strings in Dart.
- Keep punctuation and capitalization consistent with the English source.
- If a string is not ready for translation, leave it in the English template and
  open an issue rather than shipping a placeholder translation.
- Cubits/services without a `BuildContext` should pass raw data to the UI and let
  the UI call `AppLocalizations`.

## Verifying

```bash
flutter gen-l10n
flutter analyze --no-fatal-infos
flutter run -d <device-id>
```

Then switch languages in the app and check the changed screens, dialogs, and
snackbars. Pay particular attention to long strings, pluralization, and
right-to-left readiness if a future locale requires it.

## Related documents

- [Code style](code-style.md)
- [Contributing](../../CONTRIBUTING.md)
- [Architecture](../../ARCHITECTURE.md#10-localization)
