# Main Agent (vizion-agent-builder)

## Purpose
Owns orchestration for the `vizion-agent-builder` workspace.

## Responsibilities
- Maintain a clear interface for inputs/outputs (files, DB tables, workflow triggers).
- Delegate scoped tasks to worker agents under `agents/workers`.
- Enforce workspace conventions and keep changes reproducible.

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
