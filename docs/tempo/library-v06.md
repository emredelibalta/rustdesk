# Tempo library v0.6

- Select version first (for example V17 / 08b), then Fly, Jump, Run or Müşavir.
- Package titles are bold. URLs, test status and dates are not shown in list rows; the edit dialog retains the underlying metadata.
- Add the user-provided V17 / 07d Partner link to all four product lists. It is one shared installer URL, not four independently verified installers. Do not relabel it as 08b.
- Loading existing catalogs and saving imports adds missing Partner entries while preserving custom records, including an existing Partner entry with a custom URL/status. Repeated loading does not duplicate entries.
- The version selector filters catalog records. It does not scan the CDN for unpublished/new versions.

Regression surface:
- `flutter/lib/desktop/tempo/catalog.dart`: accepts the Partner package kind and adds the four missing built-in entries. This is required for reading, editing and exporting Partner records.
- `flutter/lib/desktop/tempo/library_button.dart`: merges missing entries during load/save, adds the version filter ahead of product selection, and simplifies list rows. Existing HTTPS validation, download authorization and same-product/version guards remain.
- `flutter/test/tempo_catalog_test.dart`: adds a regression for four-product Partner defaults, preserving existing records and idempotent merge/import.
- `.github/workflows/tempo-library-ui-test.yml`: builds only the changed Flutter UI using the previously verified native DLL and bridge. A source diff guard refuses native source changes, and SHA256 checks the DLL before and after assembly.

Validation: pure Dart catalog tests pass. Windows Flutter checks/build run in GitHub Actions. Live remote downloads and the previously reported customer ID/terminal progress issues are separate from this library UI change.
