# ZEDPROXYBOT-v2

One-command installer:

```bash
bash install.sh
```

## Installer menu (English)
1. Install bot
2. Update bot
3. Uninstall bot
4. Backup database
5. Restore database
6. Restart services
7. Show services status
8. Show bot logs
9. Show app logs
10. Exit

## Notes
- Telegram bot UI and messages are Persian.
- Installer and terminal messages are English.
- Bot token is validated via Telegram `getMe` during install.
- Default runtime mode is polling (`USE_WEBHOOK=false`).
- In polling mode, previous webhook is deleted before `start_polling`.
- `.env` is not overwritten by update flow.
- Financial settings are intentionally not asked during install.
- Defaults: `CARD_NUMBER=`, `CARD_HOLDER=`, `K2K_ENABLED=false`.

## Health check
```bash
curl http://127.0.0.1:8000/health
```
Expected response:
```json
{"status":"ok"}
```
