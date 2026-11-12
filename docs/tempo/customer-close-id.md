# TempoDestek portable close / ID test v0.9

The customer page now polls the existing mainGetMyId FFI once per second. It displays/copies the raw returned ID instead of a controller whose polling previously lived only in DesktopHomePage. Ready status requires both a nonempty ID and a connected server.

Main-window X/taskbar close in the TEMPO_CUSTOMER build now calls the same explicit exit flow as the new Desteği bitir ve kapat button: request stop-service, release portable shared memory using the existing FFI close hook, then exit the current process. It does not kill processes by name. The native portable server runs in that UI process. Normal operator/Host builds retain their original close path.

Regression surface: customer_page.dart adds bounded ID polling and cancels it on disposal; identity.dart adds/test-covers real readiness; lifecycle.dart owns customer-only shutdown; tabbar_widget.dart adds one compile-flag/main-window hook. No Rust/FFI signatures change. The Windows packaging workflow refuses native source differences, verifies the original customer EXE SHA256, reuses its exact native DLL and inserts changed Flutter files using the project's existing RDPKG resource format.

Acceptance: fully exit the OLD TempoDestek.exe first (the old X only hides it). Open the new EXE, fill/restore identity and click ready. Confirm ID appears. Test X, Alt+F4 and Desteği bitir ve kapat with/without an active connection: no main TempoDestek.exe should remain. Check that the operator sees the peer go offline after normal heartbeat expiry. Test elevated portable support separately and confirm installed Tempo Host is unaffected. Runtime Windows/AV acceptance is not implied by compilation/unit tests.
