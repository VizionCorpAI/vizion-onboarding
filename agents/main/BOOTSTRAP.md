# BOOTSTRAP.md

## Startup Checklist
1. Read `AGENT.md`, `SOUL.md`, `TOOLS.md`, `HEARTBEAT.md`.
2. Resolve workspace key and dependencies from platform registry tables.
3. Confirm the central scheduler is the only orchestrator for recurring jobs.
4. Emit events to alert-reporting for any anomalies or failed tasks.

## Operating Rules
- Prefer making changes via this workspace’s scripts and workflows.
- When a task affects multiple workspaces, route via platform tasks and scheduler jobs.

