# Channel Onboarding

## Inputs
- CLIENT_NAME (required)
- CLIENT_KEY (optional; derived from CLIENT_NAME)
- CLIENT_ALIASES (optional JSON array)
- CHANNELS_JSON (preferred) or WHATSAPP_NUMBER/TELEGRAM_NUMBER
- AGENTS_JSON (optional JSON array of agent keys)

## CHANNELS_JSON format
```json
[
  {"domain":"SOCIAL","kind":"WHATSAPP","identifier":"PRIMARY_PHONE","value":"+17373934343"},
  {"domain":"SOCIAL","kind":"TELEGRAM","identifier":"PRIMARY_PHONE","value":"+17373934343"}
]
```

## Output
- Infisical secret keys are created using the universal format.
- A client catalog file is written under `state/clients/` (no secret values).
- An index map secret `CLIENT_<KEY>__SOCIAL__CHANNELS__INDEX_JSON` is written with key references.

## OpenClaw checks
Preflight verifies:
- OpenClaw config exists and is valid JSON
- channels.*.enabled is true for requested kinds
- dmPolicy is `allowlist`
- allowFrom is not empty

Set `STRICT_MODE=1` to fail the onboarding if any check is invalid.

Set `N8N_URL` if n8n is not on `http://127.0.0.1:5678`.

## Running
```bash
CLIENT_NAME="Long John Silver" \
CLIENT_ALIASES='["LJ","LJS","Long John","Silver"]' \
CHANNELS_JSON='[{"domain":"SOCIAL","kind":"WHATSAPP","identifier":"PRIMARY_PHONE","value":"+17373934343"}]' \
./scripts/onboard.sh default
```

## Request-based onboarding
```bash
./scripts/onboard_request.sh templates/onboarding/request_example.json
```

## Profiles
Use `profile` in the request to select:
- `default`
- `client_full`
- `workspace_full`
- `full_stack`
