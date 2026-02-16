# Agents (vizion-onboarding)

This folder contains workspace-scoped agents.

Conventions:
- `agents/main`: the primary orchestrator agent for this workspace.
- `agents/workers`: specialized worker agents called by `main`.
- Keep credentials out of git; use environment variables or non-committed files under `secrets/` (if present).
