# Secret Key Format

All onboarding secrets use the label-based universal key format:

`CLIENT_<CLIENTKEY>__<DOMAIN>__<KIND>__<IDENTIFIER>`

## Examples
- `CLIENT_LONGJOHNSILVER__SOCIAL__WHATSAPP__PRIMARY_PHONE`
- `CLIENT_LONGJOHNSILVER__SOCIAL__TELEGRAM__PRIMARY_PHONE`
- `CLIENT_LONGJOHNSILVER__AUTH__EMAIL__PRIMARY_EMAIL`
- `CLIENT_LONGJOHNSILVER__API__HUBSPOT__TOKEN`

## Identifier conventions
- `PRIMARY_PHONE`, `SECONDARY_PHONE`
- `PRIMARY_EMAIL`, `BILLING_EMAIL`
- `PRIMARY_USERNAME`, `PRIMARY_HANDLE`
- `ADMIN_LOGIN`, `OPS_CONTACT`

Values live only in Infisical. Repos store only key names.

## Channel index
`CLIENT_<CLIENTKEY>__SOCIAL__CHANNELS__INDEX_JSON` stores a JSON map of
channel type -> identifier -> secret key name. No secret values.

See `docs/standards/identifier_guide.md` for identifier naming.
