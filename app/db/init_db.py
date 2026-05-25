from pathlib import Path
from app.core.config import settings

_STATE_FILE = Path("/tmp/zedproxybot_init_state.txt")


def ensure_main_admin(telegram_id: int) -> None:
    _STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    existing = _STATE_FILE.read_text(encoding="utf-8") if _STATE_FILE.exists() else ""
    if f"owner={settings.MAIN_ADMIN_ID}" not in existing:
        _STATE_FILE.write_text(
            f"owner={settings.MAIN_ADMIN_ID}\nlast_seen={telegram_id}\n",
            encoding="utf-8",
        )


def ensure_defaults() -> None:
    ensure_main_admin(settings.MAIN_ADMIN_ID)


def main() -> None:
    ensure_defaults()
    print("init_db completed")


if __name__ == "__main__":
    main()
