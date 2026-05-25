#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_DIR="/opt/zedproxybot"
REPO_URL="https://github.com/Mhoseinshah1/ZEDPROXYBOT-v2.git"
BACKUP_DIR="$INSTALL_DIR/backups"

log() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
err() { echo "[ERROR] $*" >&2; }

ensure_install_dir() {
  mkdir -p /opt
  mkdir -p "$INSTALL_DIR"
}

enter_install_dir() {
  cd "$INSTALL_DIR"
}

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
    return
  fi

  if command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
    return
  fi

  err "Docker Compose is not installed. Install docker compose plugin or docker-compose first."
  exit 1
}

require_cmds() {
  for c in git curl openssl; do
    if ! command -v "$c" >/dev/null 2>&1; then
      log "Installing missing dependency: $c"
      apt-get update -y
      apt-get install -y "$c"
    fi
  done
}

install_docker_if_needed() {
  if command -v docker >/dev/null 2>&1; then
    if docker ps >/dev/null 2>&1; then
      return
    fi
  fi

  if ! command -v docker >/dev/null 2>&1; then
    log "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
  fi

  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now docker >/dev/null 2>&1 || true
  fi

  if ! docker ps >/dev/null 2>&1; then
    service docker start >/dev/null 2>&1 || true
  fi

  if ! docker ps >/dev/null 2>&1; then
    err "Docker daemon is not running. Start Docker manually and retry."
    exit 1
  fi

  if ! compose_cmd >/dev/null 2>&1; then
    log "Installing Docker Compose plugin..."
    apt-get update -y
    apt-get install -y docker-compose-plugin || true
  fi

  if ! compose_cmd >/dev/null 2>&1; then
    log "Installing legacy docker-compose..."
    apt-get install -y docker-compose || true
  fi

  compose_cmd >/dev/null 2>&1 || {
    err "Docker Compose installation failed."
    exit 1
  }
}

ensure_repo_present() {
  ensure_install_dir

  if [[ -d "$INSTALL_DIR/.git" ]]; then
    log "Repository already exists at $INSTALL_DIR. Keeping existing files."
    return
  fi

  if [[ -n "$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    err "Install directory $INSTALL_DIR exists but is not a git repository."
    err "Please move or clean this directory manually, then run installer again."
    exit 1
  fi

  log "Cloning repository into $INSTALL_DIR"
  git clone "$REPO_URL" "$INSTALL_DIR"
}

require_compose_file() {
  enter_install_dir

  if [[ ! -f "$INSTALL_DIR/docker-compose.yml" ]]; then
    err "docker-compose.yml not found in $INSTALL_DIR. Repository may not have been cloned correctly."
    exit 1
  fi
}

validate_token() {
  local token="$1"
  local resp

  resp="$(curl -sS "https://api.telegram.org/bot${token}/getMe" || true)"

  if [[ "$resp" != *'"ok":true'* ]]; then
    err "Invalid Bot Token. Telegram getMe validation failed."
    exit 1
  fi

  log "Bot token validated successfully."
}

write_env() {
  local db_pass="$1"

  ensure_install_dir

  cat > "$INSTALL_DIR/.env" <<ENV
APP_NAME=ZED Proxy Bot
ENV=production
BOT_TOKEN=$BOT_TOKEN
MAIN_ADMIN_ID=$MAIN_ADMIN_ID
ADMIN_USERNAME=$ADMIN_USERNAME
ADMIN_PASSWORD=$ADMIN_PASSWORD
JWT_SECRET=$(openssl rand -hex 32)
JWT_EXPIRE_MINUTES=60
DATABASE_URL=postgresql+asyncpg://$DB_USER:$db_pass@db:5432/$DB_NAME
REDIS_URL=${REDIS_URL:-redis://redis:6379/0}
DOMAIN=${DOMAIN:-}
WEB_BASE_URL=http://127.0.0.1:8000
USE_WEBHOOK=false
BOT_WEBHOOK_PATH=/telegram/webhook
ADMIN_PATH=/admin
API_PATH=/api
CARD_NUMBER=
CARD_HOLDER=
K2K_ENABLED=false
REPORT_GROUP_CHAT_ID=${REPORT_GROUP_CHAT_ID:-}
REPORT_GROUP_ENABLED=$([[ -n "${REPORT_GROUP_CHAT_ID:-}" ]] && echo "true" || echo "false")
FORCE_JOIN_ENABLED=false
FORCE_PHONE_ENABLED=false
POSTGRES_DB=$DB_NAME
POSTGRES_USER=$DB_USER
POSTGRES_PASSWORD=$db_pass
ENV

  log ".env created at $INSTALL_DIR/.env"
}

health_check() {
  sleep 5

  if curl -fsS http://127.0.0.1:8000/health >/dev/null 2>&1; then
    log "Health check passed."
  else
    warn "Health check failed. Check app logs."
  fi
}

run_migrations_and_seed() {
  enter_install_dir
  require_compose_file

  local cc
  cc="$(compose_cmd)"

  $cc exec -T app sh -c 'alembic upgrade head || true'
  $cc exec -T app python -m app.db.init_db || true
}

install_bot() {
  require_cmds
  install_docker_if_needed
  ensure_repo_present
  require_compose_file
  enter_install_dir

  if [[ -f "$INSTALL_DIR/.env" ]]; then
    warn ".env already exists. It will not be overwritten."
  else
    read -r -p "Bot Token: " BOT_TOKEN
    validate_token "$BOT_TOKEN"

    read -r -p "Main Admin Telegram ID: " MAIN_ADMIN_ID
    read -r -p "Admin username: " ADMIN_USERNAME
    read -r -s -p "Admin password: " ADMIN_PASSWORD
    echo

    read -r -p "Domain (optional): " DOMAIN
    read -r -p "Enable SSL? (yes/no): " ENABLE_SSL
    read -r -p "Report group chat ID (optional): " REPORT_GROUP_CHAT_ID
    read -r -p "Database name [zedproxy]: " DB_NAME
    DB_NAME=${DB_NAME:-zedproxy}

    read -r -p "Database user [zedproxy]: " DB_USER
    DB_USER=${DB_USER:-zedproxy}

    read -r -s -p "Database password (leave empty for random): " DB_PASSWORD
    echo
    [[ -z "${DB_PASSWORD:-}" ]] && DB_PASSWORD="$(openssl rand -hex 12)"

    read -r -p "Redis URL (optional): " REDIS_URL

    write_env "$DB_PASSWORD"
  fi

  local cc
  cc="$(compose_cmd)"

  mkdir -p "$BACKUP_DIR"

  enter_install_dir
  $cc up -d db redis

  log "Waiting for database..."
  sleep 8

  $cc up -d --build app bot nginx
  run_migrations_and_seed || true

  $cc ps
  health_check

  echo
  log "Install finished."
  echo "Bot logs: cd $INSTALL_DIR && $(compose_cmd) logs -f bot"
  echo "App logs: cd $INSTALL_DIR && $(compose_cmd) logs -f app"

  if [[ -n "${DOMAIN:-}" ]]; then
    warn "Domain provided. Webhook remains disabled. Polling mode is used by default."
    if [[ "${ENABLE_SSL,,}" == "yes" ]]; then
      warn "SSL automation is not enabled in this safe installer yet. Configure certbot after DNS is ready."
    fi
  fi
}

backup_database() {
  ensure_repo_present
  require_compose_file
  enter_install_dir

  local cc
  cc="$(compose_cmd)"

  mkdir -p "$BACKUP_DIR"

  local ts
  ts="$(date +%Y%m%d_%H%M%S)"

  local env_file="$INSTALL_DIR/.env"
  local db_user="zedproxy"
  local db_name="zedproxy"

  if [[ -f "$env_file" ]]; then
    db_user="$(grep -E '^POSTGRES_USER=' "$env_file" | cut -d= -f2- || true)"
    db_name="$(grep -E '^POSTGRES_DB=' "$env_file" | cut -d= -f2- || true)"
    db_user="${db_user:-zedproxy}"
    db_name="${db_name:-zedproxy}"
  fi

  $cc exec -T db pg_dump -U "$db_user" "$db_name" > "$BACKUP_DIR/db_$ts.sql"
  log "Backup saved: $BACKUP_DIR/db_$ts.sql"
}

restore_database() {
  ensure_repo_present
  require_compose_file
  enter_install_dir

  local cc
  cc="$(compose_cmd)"

  mapfile -t files < <(find "$BACKUP_DIR" -maxdepth 1 -name 'db_*.sql' 2>/dev/null | sort)

  if [[ ${#files[@]} -eq 0 ]]; then
    warn "No backups found."
    return
  fi

  echo "Available backups:"
  select f in "${files[@]}"; do
    [[ -n "$f" ]] || continue

    read -r -p "Restore selected backup? (yes/no): " ans
    [[ "${ans,,}" == "yes" ]] || return

    local env_file="$INSTALL_DIR/.env"
    local db_user="zedproxy"
    local db_name="zedproxy"

    if [[ -f "$env_file" ]]; then
      db_user="$(grep -E '^POSTGRES_USER=' "$env_file" | cut -d= -f2- || true)"
      db_name="$(grep -E '^POSTGRES_DB=' "$env_file" | cut -d= -f2- || true)"
      db_user="${db_user:-zedproxy}"
      db_name="${db_name:-zedproxy}"
    fi

    cat "$f" | $cc exec -T db psql -U "$db_user" -d "$db_name"
    log "Restore completed."
    break
  done
}

update_bot() {
  require_cmds
  install_docker_if_needed
  ensure_repo_present
  require_compose_file
  enter_install_dir

  local cc
  cc="$(compose_cmd)"

  backup_database || warn "Backup failed, continuing update."

  git checkout main
  git fetch origin
  git pull origin main

  $cc up -d --build
  run_migrations_and_seed || true
  $cc restart app bot
  $cc ps
  health_check

  log "Update completed."
}

uninstall_bot() {
  ensure_repo_present
  require_compose_file
  enter_install_dir

  local cc
  cc="$(compose_cmd)"

  read -r -p "Are you sure? (yes/no): " ans
  [[ "${ans,,}" == "yes" ]] || return

  read -r -p "Take backup first? (yes/no): " b
  [[ "${b,,}" == "yes" ]] && backup_database

  $cc down

  read -r -p "Remove volumes too? (yes/no): " rv
  [[ "${rv,,}" == "yes" ]] && $cc down -v

  read -r -p "Remove project files too? (yes/no): " rf
  [[ "${rf,,}" == "yes" ]] && rm -rf "$INSTALL_DIR"

  log "Uninstall completed."
}

restart_services() {
  ensure_repo_present
  require_compose_file
  enter_install_dir

  $(compose_cmd) restart app bot
}

show_status() {
  ensure_repo_present
  require_compose_file
  enter_install_dir

  $(compose_cmd) ps
}

show_bot_logs() {
  ensure_repo_present
  require_compose_file
  enter_install_dir

  $(compose_cmd) logs -f bot
}

show_app_logs() {
  ensure_repo_present
  require_compose_file
  enter_install_dir

  $(compose_cmd) logs -f app
}

while true; do
  echo
  echo "=== ZED VPN Bot Installer ==="
  echo "1. Install bot"
  echo "2. Update bot"
  echo "3. Uninstall bot"
  echo "4. Backup database"
  echo "5. Restore database"
  echo "6. Restart services"
  echo "7. Show services status"
  echo "8. Show bot logs"
  echo "9. Show app logs"
  echo "10. Exit"

  read -r -p "Choose an option: " opt

  case "$opt" in
    1) install_bot ;;
    2) update_bot ;;
    3) uninstall_bot ;;
    4) backup_database ;;
    5) restore_database ;;
    6) restart_services ;;
    7) show_status ;;
    8) show_bot_logs ;;
    9) show_app_logs ;;
    10) exit 0 ;;
    *) warn "Invalid option" ;;
  esac
done