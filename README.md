# vizion-onboarding

Onboarding automation and templates for VizionAI.
Use these docs from humans, agents, workflows, and onboarding services.

## Architecture
- Canonical system architecture: `../vizion-infra/wiki/architecture/README.md`
- Onboarding-specific architecture: `docs/TELEGRAM_ARCHITECTURE.md`
- Policy hub: `../vizion-security/docs/POLICY_INDEX.md`
- Policy manifest: `../vizion-security/docs/POLICY_INDEX.json`

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
