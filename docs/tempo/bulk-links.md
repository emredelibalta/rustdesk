# Bulk Mikro links v0.9

Toplu paket ekle selects a product and V17 update version, then shows an editable list of installer filenames. Full URLs are constructed as `https://cdn-mikro.atros.com.tr/mikro/v17/<version>/<filename>`. A product's previously saved filenames override suggested defaults, so correcting names once carries forward to later versions. Suggested product prefixes are candidates, not confirmed installer names; first-time Müşavir/Jump/Run names may need correction.

Before saving, each URL is requested with a 2-byte range. The response must be HTTPS, HTTP 200/206 and have the expected PE/MSI header. The connection is closed after that header; the operator does not archive the EXE. This is availability/header checking, not a signature or compatibility guarantee. Actual customer downloads retain full signature checks. Missing/invalid links are listed and not saved.

Valid records are inserted or updated by product/major/version/package key, preserving an existing ID/status/note. Other versions remain. The manual Tek paket editor remains for nonstandard URLs. The library still resides on the operator PC; no central Leaseweb service is deployed by this change.

Regression surface: bulk_catalog.dart contains filename templates, URL generation and availability probes; library_button.dart adds the bulk dialog and merge/status handling; the existing catalog save path performs persistence/backup; tempo_bulk_catalog_test.dart covers exact URL generation and replacement identity and rejects path/full-URL/duplicate-kind input. The UI-only Windows workflow adds these tests and reuses the hash-verified unchanged native DLL.
