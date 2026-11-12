# TempoDestek Test 0.11 CRM queue
Prepared locally, not built or deployed. Based on 7d45d02d1c5fc1b2b21c06422df3d321f5e6f70e.

Customer name, tax number, topic and RustDesk ID use the existing CRM intake endpoint.
Request secret is generated per request, not a server API key. Pulse interval is 25s;
CRM expires presence after 90s. Close sends a best-effort cancellation. Actual remote
connection still requires customer approval and staff RustDesk login.
TEMPO_CRM_INTAKE can override the public intake URL at compile time.

Regression surface: customer_page.dart adds topic and readiness-triggered registration/
presence; lifecycle.dart sends cancellation before the existing close path. New crm_queue.dart
contains HTTP protocol. Only the customer workflow branch/artifact name changes. Native,
FFI, operator and Host behavior unchanged. Existing customer tests must run in Windows CI;
then test network failure, X-close, repeated start and correct CRM company/person matching.

GitHub upload/build awaits user's explicit authorization after automatic review rejection.
