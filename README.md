# vizion-onboarding

Workspace control plane for onboarding workflows, agents, channels, and infrastructure catalogs.

## Structure
- `modules/`: atomic onboarding steps (workspace scaffolding, agent generation, channel seeding).
- `profiles/`: module compositions (default, infra-only, client-channel deploys).
- `templates/`: scaffolding for agents, workspaces, and n8n workflows.
- `tasks/manifest.yaml`: declares onboarding tasks/load order.
- `scripts/`: orchestrators (e.g., `onboard.sh`) and module helpers.
- `workflows/n8n/`: webhook-driven flows that trigger onboarding via platform.
- `agents/`, `infra/`, `config/`, `state/`: supporting artifacts (unchanged).

## Alignment Keys
- workspace_key: onboarding
- workflow_namespace: onboarding
