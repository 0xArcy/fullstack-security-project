#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKEND_DIR="${PROJECT_ROOT}/backend"

usage() {
  cat <<'USAGE'
Usage: setup-backend.sh [options]

Required:
  --db-host <host>                MongoDB host/IP.
  --frontend-origin <origin>      Allowed frontend origin (example: https://app.example.com).

Optional:
  --db-port <port>                MongoDB port (default: 27017).
  --db-name <name>                MongoDB database (default: secure_db).
  --db-user <user>                MongoDB app user (default: secure_app_user).
  --db-pass <password>            MongoDB app password.
  --creds-file <path>             Source DB variables from env file (from setup-database.sh output).
  --backend-port <port>           API port (default: 3000).
  --proxy-ip <ip>                 Restrict firewall rule for port 3000 to this proxy IP.
  --mongo-tls-ca-file <path>      TLS CA cert path for MongoDB validation.
  --mongo-tls-allow-invalid-certs Allow invalid MongoDB TLS certs (default: false).
  --force-env                     Overwrite backend/.env if it exists.
  --skip-upgrade                  Skip apt-get upgrade.
  -h, --help                      Show this help.

Environment variable alternatives:
  DB_HOST DB_PORT DB_NAME DB_USER DB_PASS FRONTEND_ORIGIN BACKEND_PORT PROXY_IP
  CREDS_FILE MONGO_TLS_CA_FILE MONGO_TLS_CA_B64 MONGO_TLS_ALLOW_INVALID_CERTS FORCE_ENV SKIP_UPGRADE
USAGE
}

DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-27017}"
DB_NAME="${DB_NAME:-secure_db}"
DB_USER="${DB_USER:-secure_app_user}"
DB_PASS="${DB_PASS:-}"
FRONTEND_ORIGIN="${FRONTEND_ORIGIN:-}"
BACKEND_PORT="${BACKEND_PORT:-3000}"
PROXY_IP="${PROXY_IP:-}"
CREDS_FILE="${CREDS_FILE:-}"
MONGO_TLS_CA_FILE="${MONGO_TLS_CA_FILE:-}"
MONGO_TLS_CA_B64="${MONGO_TLS_CA_B64:-}"
MONGO_TLS_ALLOW_INVALID_CERTS="${MONGO_TLS_ALLOW_INVALID_CERTS:-false}"
FORCE_ENV="${FORCE_ENV:-false}"
SKIP_UPGRADE="${SKIP_UPGRADE:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-host)
      DB_HOST="$2"
      shift 2
      ;;
    --db-port)
      DB_PORT="$2"
      shift 2
      ;;
    --db-name)
      DB_NAME="$2"
      shift 2
      ;;
    --db-user)
      DB_USER="$2"
      shift 2
      ;;
    --db-pass)
      DB_PASS="$2"
      shift 2
      ;;
    --frontend-origin)
      FRONTEND_ORIGIN="$2"
      shift 2
      ;;
    --backend-port)
      BACKEND_PORT="$2"
      shift 2
      ;;
    --proxy-ip)
      PROXY_IP="$2"
      shift 2
      ;;
    --creds-file)
      CREDS_FILE="$2"
      shift 2
      ;;
    --mongo-tls-ca-file)
      MONGO_TLS_CA_FILE="$2"
      shift 2
      ;;
    --mongo-tls-allow-invalid-certs)
      MONGO_TLS_ALLOW_INVALID_CERTS="true"
      shift
      ;;
    --force-env)
      FORCE_ENV="true"
      shift
      ;;
    --skip-upgrade)
      SKIP_UPGRADE="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$CREDS_FILE" ]]; then
  if [[ ! -f "$CREDS_FILE" ]]; then
    echo "Credentials file not found: $CREDS_FILE" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$CREDS_FILE"
fi

if [[ -z "$DB_HOST" || -z "$FRONTEND_ORIGIN" || -z "$DB_PASS" ]]; then
  echo "Missing required settings. You must provide DB host/password and frontend origin." >&2
  usage
  exit 1
fi

if [[ -n "$MONGO_TLS_CA_B64" ]]; then
  if [[ -z "$MONGO_TLS_CA_FILE" ]]; then
    MONGO_TLS_CA_FILE="/etc/ssl/certs/mongodb-cert.crt"
  fi

  echo "[backend] Installing MongoDB CA certificate at ${MONGO_TLS_CA_FILE}..."
  sudo mkdir -p "$(dirname "$MONGO_TLS_CA_FILE")"
  echo "$MONGO_TLS_CA_B64" | base64 --decode | sudo tee "$MONGO_TLS_CA_FILE" >/dev/null
  sudo chmod 644 "$MONGO_TLS_CA_FILE"
fi

echo "[backend] Updating system packages..."
sudo apt-get update
if [[ "$SKIP_UPGRADE" != "true" ]]; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
fi

sudo apt-get install -y curl
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v | sed 's/^v//' | cut -d. -f1)" -lt 20 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

if ! command -v pm2 >/dev/null 2>&1; then
  sudo npm install -g pm2
fi

echo "[backend] Installing Node.js dependencies..."
cd "$BACKEND_DIR"
npm ci

ENCODED_DB_USER="$(node -e 'console.log(encodeURIComponent(process.argv[1]))' "$DB_USER")"
ENCODED_DB_PASS="$(node -e 'console.log(encodeURIComponent(process.argv[1]))' "$DB_PASS")"
MONGO_URI="mongodb://${ENCODED_DB_USER}:${ENCODED_DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}?authSource=admin&tls=true"

JWT_SECRET="${JWT_SECRET:-$(openssl rand -hex 32)}"
JWT_REFRESH_SECRET="${JWT_REFRESH_SECRET:-$(openssl rand -hex 32)}"
FIELD_ENCRYPT_KEY="${FIELD_ENCRYPT_KEY:-$(openssl rand -hex 32)}"

if [[ ! -f .env || "$FORCE_ENV" == "true" ]]; then
  echo "[backend] Writing backend/.env ..."
  cat > .env <<ENVVARS
PORT=${BACKEND_PORT}
NODE_ENV=production
TRUST_PROXY=1
COOKIE_SECURE=true
MONGO_URI=${MONGO_URI}
MONGO_MAX_POOL_SIZE=10
MONGO_SERVER_SELECTION_TIMEOUT_MS=5000
MONGO_TLS_CA_FILE=${MONGO_TLS_CA_FILE}
MONGO_TLS_ALLOW_INVALID_CERTS=${MONGO_TLS_ALLOW_INVALID_CERTS}
JWT_SECRET=${JWT_SECRET}
JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
FIELD_ENCRYPT_KEY=${FIELD_ENCRYPT_KEY}
ALLOWED_ORIGIN=${FRONTEND_ORIGIN}
ENVVARS
else
  echo "[backend] backend/.env exists. Use --force-env to overwrite."
fi

echo "[backend] Configuring firewall..."
sudo ufw allow ssh
if [[ -n "$PROXY_IP" ]]; then
  sudo ufw allow from "$PROXY_IP" to any port "$BACKEND_PORT" proto tcp
else
  sudo ufw allow "${BACKEND_PORT}/tcp"
fi
sudo ufw --force enable

echo "[backend] Starting API with PM2..."
if pm2 describe secure-api >/dev/null 2>&1; then
  pm2 restart secure-api --update-env
else
  pm2 start server.js --name secure-api
fi
pm2 save

echo "--------------------------------------------------------"
echo "Backend setup complete"
echo "API listening on port ${BACKEND_PORT}"
if [[ -n "$PROXY_IP" ]]; then
  echo "Firewall allows API access only from: ${PROXY_IP}"
else
  echo "Firewall allows API access from any IP (provide --proxy-ip to restrict)."
fi
echo "--------------------------------------------------------"
