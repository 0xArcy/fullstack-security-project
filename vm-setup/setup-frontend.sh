#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Using a local directory to bypass Windows/Vagrant symlink restrictions
SHARED_FRONTEND_DIR="/vagrant/frontend"
LOCAL_FRONTEND_DIR="/home/vagrant/frontend"

usage() {
  cat <<'USAGE'
Usage: setup-frontend.sh [options]

Required:
  --backend-host <host>        Backend API VM host/IP.

Optional:
  --backend-port <port>        Backend API port (default: 3000).
  --server-name <name>         Nginx server_name value (default: _).
  --skip-upgrade               Skip apt-get upgrade.
  -h, --help                   Show this help.
USAGE
}

BACKEND_HOST="${BACKEND_HOST:-}"
BACKEND_PORT="${BACKEND_PORT:-3000}"
SERVER_NAME="${SERVER_NAME:-_}"
SKIP_UPGRADE="${SKIP_UPGRADE:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend-host) BACKEND_HOST="$2"; shift 2 ;;
    --backend-port) BACKEND_PORT="$2"; shift 2 ;;
    --server-name) SERVER_NAME="$2"; shift 2 ;;
    --skip-upgrade) SKIP_UPGRADE="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$BACKEND_HOST" ]]; then
  echo "Missing required argument: --backend-host" >&2
  usage
  exit 1
fi

echo "[frontend] Updating system packages..."
sudo apt-get update
if [[ "$SKIP_UPGRADE" != "true" ]]; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
fi

sudo apt-get install -y curl nginx openssl gettext-base rsync

# --- NODE INSTALL & PATH FIX ---
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v | sed 's/^v//' | cut -d. -f1)" -lt 20 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
sudo ln -sf /usr/bin/node /usr/local/bin/node || true
sudo ln -sf /usr/bin/npm /usr/local/bin/npm || true

# --- NATIVE DIRECTORY SYNC ---
echo "[frontend] Syncing to native directory to fix Vite path issues..."
sudo mkdir -p "$LOCAL_FRONTEND_DIR"
sudo chown -R vagrant:vagrant "$LOCAL_FRONTEND_DIR"

# Sync files while excluding node_modules to ensure a fresh, native build
rsync -av --delete --exclude='node_modules' "$SHARED_FRONTEND_DIR/" "$LOCAL_FRONTEND_DIR/"

cd "$LOCAL_FRONTEND_DIR"

echo "[frontend] Installing dependencies and building React app..."
# We use npm install instead of ci here to ensure it handles the native environment fresh
npm install
# Force the use of the local vite binary
./node_modules/.bin/vite build

echo "[frontend] Deploying static assets..."
sudo mkdir -p /var/www/frontend
sudo rm -rf /var/www/frontend/*
sudo cp -a dist/. /var/www/frontend/
sudo chown -R www-data:www-data /var/www/frontend
sudo chmod -R 755 /var/www/frontend

echo "[frontend] Rendering nginx config..."
export BACKEND_HOST BACKEND_PORT SERVER_NAME

# Point to the actual shared directory where the file lives
NGINX_CONF_SOURCE="/vagrant/vm-setup/godproxy-nginx.conf"
if [[ -f "$NGINX_CONF_SOURCE" ]]; then
  envsubst '$BACKEND_HOST $BACKEND_PORT $SERVER_NAME' \
    < "$NGINX_CONF_SOURCE" \
    | sudo tee /etc/nginx/sites-available/default >/dev/null
else
  echo "ERROR: godproxy-nginx.conf not found at $NGINX_CONF_SOURCE" >&2
  exit 1
fi

if [[ ! -f /etc/ssl/private/godproxy.key || ! -f /etc/ssl/certs/godproxy.crt ]]; then
  echo "[frontend] Generating self-signed TLS cert..."
  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/godproxy.key \
    -out /etc/ssl/certs/godproxy.crt \
    -subj "/C=US/ST=State/L=City/O=Security/CN=${SERVER_NAME}"
fi

sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "[frontend] Configuring firewall..."
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw --force enable

echo "--------------------------------------------------------"
echo "Frontend + proxy setup complete"
echo "--------------------------------------------------------"