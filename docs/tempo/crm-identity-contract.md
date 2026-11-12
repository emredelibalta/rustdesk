# CRM identity integration — proposed contract, not deployed

## Current behavior

TempoDestek saves `tempo-person` and `tempo-tax-id` locally/backend-side. Authenticated PeerInfo carries `tempo_full_name` and `tempo_tax_id` to the native operator. Pro sysinfo receives a combined preset device username. This does not add separate REST fields to RustDesk Server Pro or create a new CRM endpoint. A live server API response has not been inspected in this task.

RustDesk Pro supports token-authorized device views, with device/read permissions. Before relying on combined usernames, verify the actual server response, permissions and uploaded values. Do not use a display label as the permanent CRM data schema.

## Proposed CRM response

`GET /tempo/v1/devices/{rustdesk_id}` is a proposed endpoint, not an existing route.

```json
{
  "rustdesk_id": "175155908",
  "full_name": "Test Kullanıcısı",
  "vkn_tckn": "00123456789",
  "computer_name": "DEMO-PC",
  "identity_source": "customer_input"
}
```

All IDs are strings; preserve leading zeroes. The required identifier is 1–11 ASCII digits. Form validation is not official VKN/TCKN ownership/validity verification. Multiple devices may share an identifier; CRM matching should handle multiple candidates rather than silently attach to the first company. Online/last-seen data can be joined from Pro device state after verifying its API response.

Implementation needs an authenticated device-to-server registration flow and server-side storage for the two separate fields. Never embed a Pro administrator/API token in a portable client. CRM calls the integration server from its backend using scoped authorization. Personal data access must follow the operator/customer scope. No CRM database, server endpoint or shared library publishing service has been modified/deployed here.

Official API token/device documentation: https://rustdesk.com/docs/en/self-host/rustdesk-server-pro/console/ .
