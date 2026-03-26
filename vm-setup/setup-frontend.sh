#!/bin/bash
# setup-frontend.sh - Run this on VM 1 (Frontend & Godproxy)

echo "Please insert the internal IP address of VM 2 (Backend VM):"
read BACKEND_IP

echo "1. Updating system..."
sudo apt-get update && sudo apt-get upgrade -y

echo "2. Installing Node.js, npm & Nginx..."
sudo apt-get install -y curl
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs npm nginx

echo "3. Building the Secure React Application..."
cd ../frontend
npm install
# Ensures the base URL points to the proxy
echo "VITE_API_URL=/api" > .env
npm run build 

echo "4. Deploying Frontend to Web Root..."
sudo mkdir -p /var/www/frontend
# Ensure we copy contents correctly even with hidden files
sudo cp -a dist/. /var/www/frontend/ 
sudo chown -R www-data:www-data /var/www/frontend
sudo chmod -R 755 /var/www/frontend

echo "5. Configuring Godproxy (Nginx Proxy API)..."
cd ../vm-setup
# Dynamically insert the Backend IP
sed -i "s/<backend_vm_ip>/${BACKEND_IP}/g" godproxy-nginx.conf
sudo cp godproxy-nginx.conf /etc/nginx/sites-available/default

echo "6. Generating TLS Certificates for HTTP strictness..."
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/godproxy.key \
    -out /etc/ssl/certs/godproxy.crt \
    -subj "/C=US/ST=State/L=City/O=Security/CN=secure-app.local"

# Fix Nginx Hash Bucket Size for longer domains if needed
sudo sed -i 's/# server_names_hash_bucket_size 64;/server_names_hash_bucket_size 128;/g' /etc/nginx/nginx.conf

sudo nginx -t && sudo systemctl restart nginx
sudo systemctl enable nginx

echo "7. Setting up UFW Firewall..."
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw --force enable

echo "--------------------------------------------------------"
echo "Frontend & Godproxy VM Setup Complete!"
echo "Access your app at: https://[this_VM_IP]/"
echo "Note: The web page is securely routing /api/ to $BACKEND_IP"
echo "--------------------------------------------------------"