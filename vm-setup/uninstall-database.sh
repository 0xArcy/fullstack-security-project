#!/usr/bin/env bash
set -euo pipefail

echo "[database-uninstall] Stopping MongoDB service..."
sudo systemctl stop mongod || true
sudo systemctl disable mongod || true

echo "[database-uninstall] Removing MongoDB packages..."
sudo apt-get purge -y "mongodb-org*" || true
sudo apt-get autoremove -y || true

echo "[database-uninstall] Removing data and log directories..."
sudo rm -rf /var/log/mongodb
sudo rm -rf /var/lib/mongodb
sudo rm -rf /var/run/mongodb

echo "[database-uninstall] Removing configuration and certificates..."
sudo rm -f /etc/mongod.conf
sudo rm -f /etc/ssl/mongodb.pem
sudo rm -f /etc/ssl/certs/mongodb-cert.crt

echo "[database-uninstall] Removing APT sources and GPG keys..."
sudo rm -f /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo rm -f /usr/share/keyrings/mongodb-server-7.0.gpg

echo "--------------------------------------------------------"
echo "Database uninstallation and cleanup complete."
echo "--------------------------------------------------------"
