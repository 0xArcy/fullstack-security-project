#!/bin/bash
# setup-database.sh - Run this on VM 3 (Database)

echo "1. Updating system..."
sudo apt-get update && sudo apt-get upgrade -y

echo "2. Installing MongoDB 7.0..."
sudo apt-get install -y gnupg curl
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor --yes
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

sudo apt-get update
sudo apt-get install -y mongodb-org

echo "3. Generating Self-Signed TLS Certificates for MongoDB..."
sudo openssl req -newkey rsa:2048 -new -x509 -days 365 -nodes \
    -out mongodb-cert.crt -keyout mongodb-cert.key \
    -subj "/C=US/ST=State/L=City/O=Security/CN=mongodb.local"

# Combine into a single .pem file which MongoDB requires
cat mongodb-cert.key mongodb-cert.crt | sudo tee /etc/ssl/mongodb.pem > /dev/null
sudo chown mongodb:mongodb /etc/ssl/mongodb.pem
sudo chmod 600 /etc/ssl/mongodb.pem

echo "4. Configuring mongod.conf for TLS & Authentication..."
sudo bash -c 'cat > /etc/mongod.conf <<EOF
storage:
  dbPath: /var/lib/mongodb
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
net:
  port: 27017
  bindIp: 0.0.0.0
  tls:
    mode: requireTLS
    certificateKeyFile: /etc/ssl/mongodb.pem
security:
  authorization: enabled
EOF'

echo "5. Temporarily bypassing Auth to create Database User..."
sudo sed -i 's/mode: requireTLS/mode: disabled/' /etc/mongod.conf
sudo sed -i 's/authorization: enabled/authorization: disabled/' /etc/mongod.conf
sudo systemctl enable mongod
sudo systemctl restart mongod
sleep 5 # wait for boot

echo "6. Creating restricted Database User..."
DB_USER="secure_app_user"
DB_PASS="SecureOpsPass123!" 
mongosh admin --eval "
  db.createUser({
    user: '${DB_USER}',
    pwd: '${DB_PASS}',
    roles: [ { role: 'readWrite', db: 'secure_db' } ]
  })
"

echo "7. Re-Enabling TLS and Authentication..."
sudo sed -i 's/mode: disabled/mode: requireTLS/' /etc/mongod.conf
sudo sed -i 's/authorization: disabled/authorization: enabled/' /etc/mongod.conf
sudo systemctl restart mongod

echo "8. Setting up UFW Firewall..."
sudo ufw allow ssh
sudo ufw allow 27017/tcp
sudo ufw --force enable

echo "--------------------------------------------------------"
echo "Database VM Setup Complete! TLS is enforced."
echo "DB_USER: ${DB_USER}"
echo "DB_PASS: ${DB_PASS}"
echo "--------------------------------------------------------"