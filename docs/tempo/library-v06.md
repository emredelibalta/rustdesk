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

## Demo and auxiliary tools v0.7

The library title now opens **Demo Kurulumu** and **E-Uygulamalar / Başlıklar**. New local headings and named version/architecture links are stored in `%LOCALAPPDATA%/TempoAraclari/uygulamalar.json`, separately from Mikro records. JSON export/import shares a snapshot and backs up the previous file. There is no centralized endpoint or write API configured; edits do not automatically reach other operators.

Built-in headings include E-Uygulamalar, Mikro Demo Paketleri and Yardımcı Araçlar. Java/AKİS/demo links must be supplied by the operator; none are guessed. Auxiliary downloads allow HTTPS EXE/MSI and ZIP/JAR. Executable installers require valid Authenticode; ZIP/JAR files are downloaded without extraction/execution and checked for a ZIP header. No auxiliary installer starts automatically.

Demo opens a transparent PowerShell helper on the customer's interactive Windows desktop through an authorized terminal. It uses a local script file and ordinary `-File`; it does not disable execution policy or use compressed/encoded script execution. Corporate script policy may prevent launching it. Close the terminal dialog after the helper opens to use the helper in the remote desktop. SQL work occurs on the target, not the operator PC.

Inventory reads SQL registry instances plus services, version/edition/patch, SSMS and Java/AKİS uninstall entries, computer/Windows name, console/report account, region, culture/UI languages, non-Unicode system locale, ACP/UTF-8 status, date/time patterns, separators and time zone. User culture belongs to the report account and may differ from another logged-on/RDP user's profile. The assistant does not change regional settings.

SQL installation requires an elevated real Windows user, an explicit collation choice, acceptance of media license terms and a second target/instance confirmation. It accepts locally selected full SQL2019 SQLEXPR media, requires Microsoft Authenticode and 15.x product version, extracts it, verifies SETUP.EXE and rechecks instance collisions immediately before `/ACTION=Install`. Windows authentication grants the current account SQL administration. Mixed Windows/SQL authentication is optional: enter a strong masked sa password on the target panel. It is not persisted in the catalog/helper file or sent as an operator command; SQL Setup receives it as a local process argument. Local administrators can inspect process arguments. TCP/Named Pipes remain disabled for the local demo configuration. No existing instance is upgraded/removed and no restart is triggered. Exit 3010 is reported as restart required; errors reference SQL Setup Summary.txt. The UI timer monitors setup without stopping the installer when the panel closes.

Official references: https://learn.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-command-prompt?view=sql-server-ver15 and https://www.microsoft.com/en-us/download/details.aspx?id=108837 . The web downloader is not passed full setup arguments; use its Download Media option to obtain SQLEXPR first.

Additional changed files/runtime paths:
- `tools_catalog.dart`: validates/persists auxiliary headings and links; builds transparent download/helper-launch commands.
- `tools_dialog.dart`: local category creation, link editing, JSON transfer, authorized download confirmation.
- `library_button.dart`: two feature buttons and optional title/status text on the existing terminal dialog; original Mikro command defaults remain.
- `flutter/assets/tempo-demo.ps1`: new opt-in inventory/install assistant, not executed by opening the library.
- `tempo_tools_catalog_test.dart`: heading/link round trip, downloads without automatic installation, and script launch without encoded execution/policy bypass.

Validation: Dart tests and PowerShell syntax/unique-instance helper tests pass. SQL installation, UAC, physical token readers, user-specific locale reporting and live Windows terminal/desktop integration still require isolated Windows acceptance testing. Previously reported portable customer ID and Mikro download percentage are not fixed by this operator-only change.
