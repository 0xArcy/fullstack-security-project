#!/bin/bash
# setup-backend.sh - Run this on VM 2 (Backend API)

echo "Please insert the IP address of VM 3 (Database):"
read DB_IP
echo "Please insert the IP address or Domain of VM 1 (Frontend Proxy):"
read FRONTEND_IP

echo "1. Installing Node, npm & PM2..."
sudo apt-get update
sudo apt-get install -y curl
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs npm
sudo npm install -g pm2

echo "2. Installing Backend Dependencies..."
cd ../backend
npm install

echo "3. Generating dynamic secure .env file..."
if [ ! -f .env ]; then
    echo "PORT=3000" > .env
    echo "MONGO_URI=mongodb://secure_app_user:SecureOpsPass123!@${DB_IP}:27017/secure_db?authSource=admin&tls=true&tlsAllowInvalidCertificates=true" >> .env
    echo "JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")" >> .env
    echo "JWT_REFRESH_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")" >> .env
    echo "FIELD_ENCRYPT_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")" >> .env
    echo "ALLOWED_ORIGIN=https://${FRONTEND_IP}" >> .env
    echo ".env file generated successfully with randomized cryptographic keys."
fi

echo "4. Checking UFW Firewall..."
sudo ufw allow ssh
sudo ufw allow 3000/tcp
sudo ufw --force enable

echo "5. Starting API SECURELY via PM2..."
pm2 start server.js --name "secure-api"
pm2 save

echo "--------------------------------------------------------"
echo "Backend VM Setup Complete! API runs on port 3000."
echo "--------------------------------------------------------"