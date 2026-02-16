# Main Agent (vizion-onboarding)

## Purpose
Owns the onboarding control plane, turning platform instructions into workspace scaffolds, agents, and channel registrations.

## Responsibilities
- Offer `scripts/onboard.sh` and `tasks/manifest.yaml` so the platform can run onboarding profiles.
- Keep `modules/`, `profiles/`, and `templates/` up to date with the latest onboarding steps.
- Capture channel metadata for WhatsApp/Telegram and expose it to Infisical/OpenClaw for downstream conditionals.

## Inputs
- Workspace registry entries (if applicable).
- Files under this workspace (`docs/`, `workflows/`, `infra/`, `sql/`).

## Outputs
- Updated workspace artifacts (agents, workflows, infra, sql, docs).
- Logs/notes in `docs/` as needed.

## Dependencies
- Other workspaces via the platform registry (if needed).

## Runbook
- Define the task.
- Identify worker(s) needed.
- Make minimal changes.
- Add verification (tests, dry-runs, lint, health checks) when possible.
