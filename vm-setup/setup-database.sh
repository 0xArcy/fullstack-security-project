#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURATION ---
BACKEND_IP="${BACKEND_IP:-}"
DB_NAME="${DB_NAME:-secure_db}"
DB_USER="${DB_USER:-secure_app_user}"
# Use the password from args/env if provided, else generate
DB_PASS="${DB_PASS:-secure_password_123}"
# CREDS_FILE="/secure-db-credentials.env"
PRIMARY_DB_IP=$(hostname -I | awk '{print $2}')
[[ -z "$PRIMARY_DB_IP" ]] && PRIMARY_DB_IP=$(hostname -I | awk '{print $1}')

echo "[database] Installing MongoDB 7.0..."
sudo apt-get update
sudo apt-get install -y gnupg curl openssl
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor --yes
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list >/dev/null
sudo apt-get update
sudo apt-get install -y mongodb-org

# 1. GENERATE CERTIFICATES
echo "[database] Generating TLS certificates..."
sudo openssl req -newkey rsa:2048 -new -x509 -days 365 -nodes \
  -out /etc/ssl/certs/mongodb-cert.crt -keyout /tmp/mongodb-cert.key \
  -subj "/C=US/ST=State/L=City/O=Security/CN=mongodb.local" \
  -addext "subjectAltName = DNS:mongodb.local,IP:${PRIMARY_DB_IP},IP:127.0.0.1"

sudo sh -c "cat /tmp/mongodb-cert.key /etc/ssl/certs/mongodb-cert.crt > /etc/ssl/mongodb.pem"
sudo chown mongodb:mongodb /etc/ssl/mongodb.pem /etc/ssl/certs/mongodb-cert.crt
sudo chmod 600 /etc/ssl/mongodb.pem
sudo chmod 644 /etc/ssl/certs/mongodb-cert.crt
rm -f /tmp/mongodb-cert.key

# 2. BOOTSTRAP USERS (No Auth, No TLS)
# We bind ONLY to 127.0.0.1 here so we can create users without auth securely
echo "[database] Bootstrapping users..."
sudo tee /etc/mongod.conf >/dev/null <<MONGOD
storage:
  dbPath: /var/lib/mongodb
net:
  port: 27017
  bindIp: 127.0.0.1
MONGOD

sudo systemctl restart mongod
sleep 5

# Create users in the 'admin' database for cleaner 'authSource=admin' logic
mongosh admin --quiet --eval "
  db.createUser({ user: '${DB_USER}', pwd: '${DB_PASS}', roles: ['root'] });
  db.getSiblingDB('${DB_NAME}').createUser({
    user: '${DB_USER}',
    pwd: '${DB_PASS}',
    roles: [{ role: 'readWrite', db: '${DB_NAME}' }]
  });
"

# 3. ENABLE FINAL SECURITY (TLS 7.0+ Compliant)
echo "[database] Hardening configuration..."
sudo tee /etc/mongod.conf >/dev/null <<MONGOD
storage:
  dbPath: /var/lib/mongodb
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
net:
  port: 27017
  bindIp: 127.0.0.1,${PRIMARY_DB_IP}
  tls:
    mode: requireTLS
    certificateKeyFile: /etc/ssl/mongodb.pem
    CAFile: /etc/ssl/certs/mongodb-cert.crt
    allowConnectionsWithoutCertificates: true
security:
  authorization: enabled
MONGOD

sudo systemctl restart mongod

# --- Bottom of setup-database.sh (Step 4) ---
echo "[database] Configuring firewall..."
sudo ufw allow ssh
sudo ufw allow from "192.168.56.11"  to any port 27017 proto tcp
sudo ufw --force enable

# Step 5: Exporting
echo "[database] Exporting credentials to shared folder..."
DB_CERT_B64="$(base64 /etc/ssl/certs/mongodb-cert.crt | tr -d '\n')"
sudo tee "$CREDS_FILE" >/dev/null <<CREDS
DB_HOST=${PRIMARY_DB_IP}
DB_PASS=${DB_PASS}
MONGO_TLS_CA_B64=${DB_CERT_B64}
CREDS
# Shared folders usually don't support 600 permissions on Windows hosts, 
# but we set it for Linux compatibility.
sudo chmod 644 "$CREDS_FILE"

echo "Database Setup Complete."