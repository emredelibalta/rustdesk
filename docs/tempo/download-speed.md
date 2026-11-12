# E-application download progress performance

The E-application download command now sets ProgressPreference to SilentlyContinue in its local script block. Windows PowerShell 5.1 progress rendering can make Invoke-WebRequest downloads much slower, especially through a remote terminal. This suppresses that built-in progress only; errors, completion output, Authenticode/ZIP checks and exact destination filenames are unchanged. Mikro downloads already use buffered HttpWebRequest with throttled progress and are not modified.

Regression surface: flutter/lib/desktop/tempo/tools_catalog.dart changes only generated E-application commands; flutter/test/tempo_tools_catalog_test.dart pins the suppression alongside existing validation checks. No Rust, protocol, customer app or SQL setup changes. Three pure Dart tests passed locally. Actual Windows 5.1 throughput comparison remains a target-machine acceptance test; no speed guarantee is made.
