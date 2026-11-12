# Customer ID display grouping

TempoDestek displays its raw numeric ID through the existing RustDesk formatID formatter: 123456789 → 123 456 789 and 48661226 → 48 661 226. Copy continues to use the raw _deviceId value. No extra digits or leading zeroes are added.

Regression surface: customer_page.dart imports and calls the existing formatter only for the visible ID text; it also identifies the build as Test 0.10 in About. Clipboard, saved identity, server startup, connection readiness and backend ID generation are unchanged. The customer UI workflow changes its artifact label and reruns its existing tests/analyzer/Windows build. No Rust or FFI change. Target-machine confirmation of ID generation was supplied by the user for Test 0.9; only display grouping is changed here.
