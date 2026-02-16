# channel_setup

Captures client channel metadata and seeds Infisical secrets using the universal key format:

`CLIENT_<CLIENTKEY>__<DOMAIN>__<KIND>__<IDENTIFIER>`

Example:
`CLIENT_LONGJOHNSILVER__SOCIAL__WHATSAPP__PRIMARY_PHONE`

Inputs:
- `CLIENT_NAME` (required)
- `CLIENT_KEY` (optional; derived from name)
- `CHANNELS_JSON` (preferred) or legacy `WHATSAPP_NUMBER` / `TELEGRAM_NUMBER`
