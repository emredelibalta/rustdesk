# Tempo customer identity test

## Behavior

TempoDestek shows the supplied Tempo Bilisim logo, connection ID and click-approval status, followed by mandatory Ad Soyad and Firma VKN/TC fields. Ad Soyad is limited to 80 characters. Firma VKN/TC accepts 1–11 ASCII digits, stored as text so leading zeroes remain intact. This is format validation only, not verification of an official tax/citizen number.

Click **Destege Hazir Ol** to save locally and start listening. Both fields are restored on the next launch; the user must press the button again. Editing requires leaving the ready state first. A separate customer approval is still required for each incoming connection. Terminal permissions and antivirus behavior are unchanged.

The two fields are persisted with existing FFI options (`tempo-person`, `tempo-tax-id`). The local UI copy restores the form; the backend copy supports peer metadata. No new FFI signature, protobuf field or submodule change is needed.

The backend adds `tempo_full_name` and `tempo_tax_id` to the existing PeerInfo.platform_additions JSON. TempoOperator renders them as a bounded toolbar label with the full value in a tooltip. Unknown/missing/invalid identity metadata adds no label; original device/user rendering remains. The combined name is also sent as the existing preset-device-username to the Pro device list. The server's existing sysinfo throttle may delay list updates for up to two minutes; manual refresh can still be required by the operator list.

## Windows acceptance checks

1. Launch TempoDestek.exe; verify the logo, ID and two required fields.
2. Leave either field blank: Destege Hazir Ol must show validation and not start readiness.
3. Enter a Turkish full name and 00123456789: leading zeroes must remain.
4. Paste letters or more than 11 digits into Firma VKN/TC: only up to 11 digits must remain.
5. Enter valid data and press Destege Hazir Ol. Connect from the updated TempoOperator, approve the connection on the customer and check the toolbar identity.
6. Close and reopen TempoDestek: both values must be restored. Press the ready button before accepting new connections.
7. Connect to an unmodified RustDesk client: original device/user labels must remain, without an empty identity badge.
8. Verify the operator home logo and existing Tempo library/terminal controls. No real terminal download is necessary for identity acceptance.

## Regression surface

- `flutter/lib/desktop/tempo_customer/customer_page.dart`: replaces the earlier prototype form with the approved required-field layout and saves through existing FFI.
- `flutter/lib/desktop/tempo_customer/identity.dart`: validates the required name and numeric identifier and parses optional peer metadata.
- `flutter/lib/desktop/widgets/remote_toolbar.dart`: adds one identity label. Existing controls and session names remain unchanged when metadata is absent.
- `flutter/lib/desktop/pages/desktop_home_page.dart`: displays the provided Tempo logo in the operator home pane.
- `src/tempo_customer.rs`: validates backend identity and appends optional identity metadata. Its existing customer build configuration and sysinfo decoration remain in place.
- `src/server/connection.rs`: rejects new connections in customer builds when required identity is missing; appends metadata before existing PeerInfo serialization. Normal builds retain their existing admission path.
- `.github/workflows/tempo-customer-test.yml` and `tempo-windows-test.yml`: run the relevant Flutter checks and produce Windows test builds.

Tests cover Turkish names, leading zeroes, required/numeric/length validation and old-client metadata fallback. Native Windows interaction and antivirus compatibility require a Windows acceptance run; a successful build alone does not establish them.
