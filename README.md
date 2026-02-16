# vizion-onboarding

Onboarding automation and templates for VizionAI.

## Secrets Standard
All secrets use the universal label-based key format:
`CLIENT_<CLIENTKEY>__<DOMAIN>__<KIND>__<IDENTIFIER>`

See `docs/standards/secret_key_format.md`.

## Onboarding Request
- Schema: `docs/schemas/onboarding_request.schema.json`
- Example: `templates/onboarding/request_example.json`
- Runner: `scripts/onboard_request.sh`

## Profiles
Profiles support multi-channel, multi-agent, and multi-workflow requests.
- `default`
- `infra`
- `client_full`
- `workspace_full`
- `full_stack`
