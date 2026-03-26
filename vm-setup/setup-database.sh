#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: setup-database.sh [options]

Options:
  --backend-ip <ip>       Restrict firewall access for MongoDB to this backend VM IP.
  --db-name <name>        Database name (default: secure_db).
  --db-user <user>        MongoDB app username (default: secure_app_user).
  --db-pass <password>    MongoDB app password (default: generated random hex).
  --bind-ip <ip-list>     mongod bindIp value (default: 0.0.0.0).
  --tls-cn <name>         TLS certificate CN (default: mongodb.local).
  --tls-san <list>        Extra SAN entries, comma-separated (example: DNS:db.local,IP:10.0.0.5).
  --creds-file <path>     Output credentials env file (default: /root/secure-db-credentials.env).
  --skip-upgrade          Skip apt-get upgrade.
  -h, --help              Show this help.

Environment variable alternatives:
  BACKEND_IP DB_NAME DB_USER DB_PASS MONGO_BIND_IP TLS_CN TLS_SAN CREDS_FILE SKIP_UPGRADE
USAGE
}

BACKEND_IP="${BACKEND_IP:-}"
DB_NAME="${DB_NAME:-secure_db}"
DB_USER="${DB_USER:-secure_app_user}"
DB_PASS="${DB_PASS:-}"
MONGO_BIND_IP="${MONGO_BIND_IP:-0.0.0.0}"
TLS_CN="${TLS_CN:-mongodb.local}"
TLS_SAN="${TLS_SAN:-}"
CREDS_FILE="${CREDS_FILE:-/root/secure-db-credentials.env}"
SKIP_UPGRADE="${SKIP_UPGRADE:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend-ip)
      BACKEND_IP="$2"
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
    --bind-ip)
      MONGO_BIND_IP="$2"
      shift 2
      ;;
    --tls-cn)
      TLS_CN="$2"
      shift 2
      ;;
    --tls-san)
      TLS_SAN="$2"
      shift 2
      ;;
    --creds-file)
      CREDS_FILE="$2"
      shift 2
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

if [[ -z "$DB_PASS" ]]; then
  DB_PASS="$(openssl rand -hex 24)"
fi

PRIMARY_DB_IP="$(hostname -I | awk '{print $1}')"
if [[ -z "$PRIMARY_DB_IP" ]]; then
  PRIMARY_DB_IP="127.0.0.1"
fi
DEFAULT_TLS_SAN="DNS:${TLS_CN},IP:${PRIMARY_DB_IP}"
if [[ -n "$TLS_SAN" ]]; then
  CERT_SAN="${DEFAULT_TLS_SAN},${TLS_SAN}"
else
  CERT_SAN="${DEFAULT_TLS_SAN}"
fi

echo "[database] Updating system packages..."
sudo apt-get update
if [[ "$SKIP_UPGRADE" != "true" ]]; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
fi

sudo apt-get install -y gnupg curl openssl

if [[ ! -f /usr/share/keyrings/mongodb-server-7.0.gpg ]]; then
  curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor --yes
fi

if [[ ! -f /etc/apt/sources.list.d/mongodb-org-7.0.list ]]; then
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list >/dev/null
fi

sudo apt-get update
sudo apt-get install -y mongodb-org

echo "[database] Generating MongoDB TLS certificates..."
sudo openssl req -newkey rsa:2048 -new -x509 -days 365 -nodes \
  -out /tmp/mongodb-cert.crt -keyout /tmp/mongodb-cert.key \
  -subj "/C=US/ST=State/L=City/O=Security/CN=${TLS_CN}" \
  -addext "subjectAltName = ${CERT_SAN}"

sudo sh -c 'cat /tmp/mongodb-cert.key /tmp/mongodb-cert.crt > /etc/ssl/mongodb.pem'
sudo cp /tmp/mongodb-cert.crt /etc/ssl/certs/mongodb-cert.crt
sudo chown mongodb:mongodb /etc/ssl/mongodb.pem
sudo chmod 600 /etc/ssl/mongodb.pem
sudo chmod 644 /etc/ssl/certs/mongodb-cert.crt
rm -f /tmp/mongodb-cert.crt /tmp/mongodb-cert.key

echo "[database] Writing mongod.conf..."
sudo tee /etc/mongod.conf >/dev/null <<MONGOD
storage:
  dbPath: /var/lib/mongodb
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
net:
  port: 27017
  bindIp: ${MONGO_BIND_IP}
  tls:
    mode: requireTLS
    certificateKeyFile: /etc/ssl/mongodb.pem
security:
  authorization: enabled
MONGOD

echo "[database] Bootstrapping database user..."
sudo sed -i 's/mode: requireTLS/mode: disabled/' /etc/mongod.conf
sudo sed -i 's/authorization: enabled/authorization: disabled/' /etc/mongod.conf
sudo systemctl enable mongod
sudo systemctl restart mongod
sleep 5

DB_USER_JSON="$(node -e 'console.log(JSON.stringify(process.argv[1]))' "$DB_USER")"
DB_PASS_JSON="$(node -e 'console.log(JSON.stringify(process.argv[1]))' "$DB_PASS")"
DB_NAME_JSON="$(node -e 'console.log(JSON.stringify(process.argv[1]))' "$DB_NAME")"

mongosh admin --quiet --eval "
const dbUser = ${DB_USER_JSON};
const dbPass = ${DB_PASS_JSON};
const dbName = ${DB_NAME_JSON};
const existing = db.getUser(dbUser);
if (!existing) {
  db.createUser({
    user: dbUser,
    pwd: dbPass,
    roles: [{ role: 'readWrite', db: dbName }]
  });
  print('created');
} else {
  print('exists');
}
"

echo "[database] Enabling TLS + auth..."
sudo sed -i 's/mode: disabled/mode: requireTLS/' /etc/mongod.conf
sudo sed -i 's/authorization: disabled/authorization: enabled/' /etc/mongod.conf
sudo systemctl restart mongod

echo "[database] Configuring firewall..."
sudo ufw allow ssh
if [[ -n "$BACKEND_IP" ]]; then
  sudo ufw allow from "$BACKEND_IP" to any port 27017 proto tcp
else
  sudo ufw allow 27017/tcp
fi
sudo ufw --force enable

DB_HOST="${PRIMARY_DB_IP}"
DB_CERT_B64="$(base64 /etc/ssl/certs/mongodb-cert.crt | tr -d '\n')"

echo "[database] Writing credentials to ${CREDS_FILE}..."
sudo mkdir -p "$(dirname "$CREDS_FILE")"
sudo tee "$CREDS_FILE" >/dev/null <<CREDS
DB_HOST=${DB_HOST}
DB_PORT=27017
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
MONGO_TLS_ALLOW_INVALID_CERTS=false
MONGO_TLS_CA_FILE=/etc/ssl/certs/mongodb-cert.crt
DB_CERT_PATH=/etc/ssl/certs/mongodb-cert.crt
MONGO_TLS_CA_B64=${DB_CERT_B64}
CREDS
sudo chmod 600 "$CREDS_FILE"

echo "--------------------------------------------------------"
echo "Database setup complete"
echo "Credentials file: ${CREDS_FILE}"
if [[ -n "$BACKEND_IP" ]]; then
  echo "Firewall allows MongoDB only from: ${BACKEND_IP}"
else
  echo "Firewall allows MongoDB from any IP (provide --backend-ip to restrict)."
fi
echo "--------------------------------------------------------"
