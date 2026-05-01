# USER.md

## Preferences
- Keep actions deterministic and auditable (logs/events)
- Route actions through `vizion-platform`; use `vizion-scheduling` only for recurring timing
- Use alert-reporting as the event bus for cross-workspace communication

## Safety
- Never commit credentials or API tokens
- Treat any secret pasted into chat as compromised; rotate it

