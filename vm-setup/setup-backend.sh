#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURATION ---
# SHARED_BACKEND_DIR="/vagrant/backend"
LOCAL_BACKEND_DIR="../backend"

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
  --creds-file <path>             Source DB variables from env file.
  --backend-port <port>           API port (default: 3000).
  --proxy-ip <ip>                 Restrict firewall rule to this proxy IP.
  --mongo-tls-ca-file <path>      TLS CA cert path.
  --mongo-tls-allow-invalid-certs Allow invalid MongoDB TLS certs (default: true).
  --force-env                     Overwrite backend/.env if it exists.
  --skip-upgrade                  Skip apt-get upgrade.
  -h, --help                      Show this help.
USAGE
}

DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-27017}"
DB_NAME="${DB_NAME:-secure_db}"
DB_USER="${DB_USER:-secure_app_user}"
DB_PASS="${DB_PASS:-}"
FRONTEND_ORIGIN="${FRONTEND_ORIGIN:-}"
CLEAN_FRONTEND_ORIGIN=$(echo "${FRONTEND_ORIGIN}" | sed 's/\/$//')
ALLOWED_ORIGINS="${CLEAN_FRONTEND_ORIGIN},https://localhost,https://127.0.0.1"
BACKEND_PORT="${BACKEND_PORT:-3000}"
PROXY_IP="${PROXY_IP:-}"
CREDS_FILE="${CREDS_FILE:-}"
MONGO_TLS_CA_FILE="${MONGO_TLS_CA_FILE:-}"
MONGO_TLS_CA_B64="${MONGO_TLS_CA_B64:-}"
# Defaulting to true for self-signed Vagrant certs
MONGO_TLS_ALLOW_INVALID_CERTS="${MONGO_TLS_ALLOW_INVALID_CERTS:-true}" 
FORCE_ENV="${FORCE_ENV:-false}"
SKIP_UPGRADE="${SKIP_UPGRADE:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-host) DB_HOST="$2"; shift 2 ;;
    --db-port) DB_PORT="$2"; shift 2 ;;
    --db-name) DB_NAME="$2"; shift 2 ;;
    --db-user) DB_USER="$2"; shift 2 ;;
    --db-pass) DB_PASS="$2"; shift 2 ;;
    --frontend-origin) FRONTEND_ORIGIN="$2"; shift 2 ;;
    --backend-port) BACKEND_PORT="$2"; shift 2 ;;
    --proxy-ip) PROXY_IP="$2"; shift 2 ;;
    --creds-file) CREDS_FILE="$2"; shift 2 ;;
    --mongo-tls-ca-file) MONGO_TLS_CA_FILE="$2"; shift 2 ;;
    --mongo-tls-allow-invalid-certs) MONGO_TLS_ALLOW_INVALID_CERTS="true"; shift ;;
    --force-env) FORCE_ENV="true"; shift ;;
    --skip-upgrade) SKIP_UPGRADE="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -n "$CREDS_FILE" && -f "$CREDS_FILE" ]]; then
  source "$CREDS_FILE"
elif [[ -f "./secure-db-credentials.env" ]]; then
  source "./secure-db-credentials.env"
fi

if [[ -z "$DB_HOST" || -z "$FRONTEND_ORIGIN" || -z "$DB_PASS" ]]; then
  echo "Missing required settings." >&2; exit 1
fi

# 1. PURGE CORRUPTED INSTALLATION
echo "[backend] Purging broken Node/NPM files..."
sudo apt-get remove -y nodejs npm || true
sudo rm -rf /usr/local/bin/npm /usr/local/bin/node /usr/local/lib/node_modules /usr/local/dist/npm.js
sudo rm -rf ~/.npm ~/.node-gyp

# 2. CLEAN INSTALL NODE.JS 20
echo "[backend] Installing fresh Node.js 20..."
sudo apt-get update
sudo apt-get install -y curl rsync build-essential python3 make g++
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 3. FIX SUDO PATHING
sudo ln -sf /usr/bin/node /usr/local/bin/node || true
sudo ln -sf /usr/bin/npm /usr/local/bin/npm || true

# 4. DECODE DB CERTIFICATE (If provided via Base64)
if [[ -n "${MONGO_TLS_CA_B64:-}" ]]; then
  echo "[backend] Decoding MongoDB CA certificate..."
  MONGO_TLS_CA_FILE="/etc/ssl/certs/mongodb-ca.crt"
  echo "$MONGO_TLS_CA_B64" | base64 -d | sudo tee "$MONGO_TLS_CA_FILE" > /dev/null
  sudo chmod 644 "$MONGO_TLS_CA_FILE"
fi

# --- 5. SYNC TO NATIVE DIRECTORY ---
echo "[backend] Syncing files..."
sudo mkdir -p "$LOCAL_BACKEND_DIR"
# CRITICAL: Ensure the directory belongs to vagrant BEFORE npm runs
sudo chown -R $USER:$USER "$LOCAL_BACKEND_DIR"
# rsync -av --delete --exclude='node_modules' "$SHARED_BACKEND_DIR/" "$LOCAL_BACKEND_DIR/"
# Re-apply ownership after rsync just in case
sudo chown -R $USER:$USER "$LOCAL_BACKEND_DIR"

# --- 6. PROJECT INSTALLATION ---
cd "$LOCAL_BACKEND_DIR"
echo "[backend] Installing dependencies as vagrant user..."
# NEVER use sudo for npm install in a local home dir
sudo -u $USER npm install --no-audit --no-fund

# 7. ENVIRONMENT SETUP
echo "[backend] Generating environment variables..."
ENCODED_DB_USER="$(node -e 'console.log(encodeURIComponent(process.argv[1]))' "$DB_USER")"
ENCODED_DB_PASS="$(node -e 'console.log(encodeURIComponent(process.argv[1]))' "$DB_PASS")"
MONGO_URI="mongodb://${ENCODED_DB_USER}:${ENCODED_DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}?authSource=secure_db&tls=true"

JWT_SECRET="${JWT_SECRET:-$(openssl rand -hex 32)}"
JWT_REFRESH_SECRET="${JWT_REFRESH_SECRET:-$(openssl rand -hex 32)}"
FIELD_ENCRYPT_KEY="${FIELD_ENCRYPT_KEY:-$(openssl rand -hex 32)}"

cat > .env <<ENVVARS
PORT=${BACKEND_PORT}
NODE_ENV=production
TRUST_PROXY=1
COOKIE_SECURE=true
MONGO_URI=${MONGO_URI}
MONGO_MAX_POOL_SIZE=10
MONGO_TLS_CA_FILE=${MONGO_TLS_CA_FILE}
MONGO_TLS_ALLOW_INVALID_CERTS=${MONGO_TLS_ALLOW_INVALID_CERTS}
JWT_SECRET=${JWT_SECRET}
JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
FIELD_ENCRYPT_KEY=${FIELD_ENCRYPT_KEY}
ALLOWED_ORIGIN=${ALLOWED_ORIGINS}
ENVVARS

# 8. FIREWALL
sudo ufw allow ssh
if [[ -n "$PROXY_IP" ]]; then
  sudo ufw allow from "$PROXY_IP" to any port "$BACKEND_PORT" proto tcp
else
  sudo ufw allow "${BACKEND_PORT}/tcp"
fi
sudo ufw --force enable

# --- 9. START APPLICATION (Direct Run) ---
echo "[backend] Starting API in the background..."

# Kill any existing node processes first
sudo killall -9 node 2>/dev/null || true

# Run the server in the background and redirect logs to a file
cd "$LOCAL_BACKEND_DIR"
sudo -u $USER nohup node server.js > ./server.log 2>&1 &

# Give it a few seconds to attempt a connection
sleep 5

echo "--------------------------------------------------------"
echo "Backend started in the background."
echo "Check connection status with: cat $LOCAL_BACKEND_DIR/server.log"
echo "--------------------------------------------------------"