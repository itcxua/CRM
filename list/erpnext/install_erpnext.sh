#!/bin/bash


# ERPNext 14+ install script for Ubuntu 22.04 with Nginx, Supervisor, and SSL (Let's Encrypt)
# Usage: ./install_erpnext.sh yourdomain.com
# chmod +x install_erpnext.sh && sudo ./install_erpnext.sh yourdomain.com
# Autor: itcxua
# Version: 1.1
# 

DOMAIN="$1"
if [ -z "$DOMAIN" ]; then
    echo "❌ Usage: $0 yourdomain.com"
    exit 1
fi

set -e

echo "📦 Updating system..."
apt update && apt upgrade -y

echo "🧰 Installing dependencies..."
apt install -y python3-dev python3-setuptools python3-pip python3-distutils                    redis-server mariadb-server mariadb-client                    software-properties-common nginx curl supervisor                    certbot python3-certbot-nginx git xvfb libfontconfig wkhtmltopdf                    libxrender1 libxext6 libxrandr2 libfreetype6 libx11-6 libxcomposite1                    libxcursor1 libxdamage1 libxi6 libxtst6 libnss3 libatk1.0-0                    libatk-bridge2.0-0 libcups2 libdrm2 libdbus-1-3 -y

echo "🧰 Installing Node.js 16 LTS..."
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt install -y nodejs

echo "🐘 Setting up MariaDB..."
systemctl enable mariadb
systemctl start mariadb
mysql -u root -e "SET GLOBAL innodb_file_format = BARRACUDA;"
mysql -u root -e "SET GLOBAL innodb_file_per_table = ON;"
mysql -u root -e "SET GLOBAL innodb_large_prefix = ON;"
mysql -u root -e "CREATE DATABASE IF NOT EXISTS erpnext;"

echo "🔧 Installing bench CLI..."
pip3 install frappe-bench

echo "📁 Initializing bench..."
mkdir -p /opt/erpnext
cd /opt/erpnext
bench init frappe-bench --frappe-branch version-14
cd frappe-bench

echo "📦 Getting ERPNext app..."
bench get-app erpnext --branch version-14
bench new-site $DOMAIN --admin-password admin --mariadb-root-password root
bench --site $DOMAIN install-app erpnext

echo "🔁 Setting up production environment..."
bench setup production $(whoami) --yes

echo "🌐 Configuring Nginx for ERPNext..."
bench setup nginx
ln -s `pwd`/config/nginx.conf /etc/nginx/sites-enabled/erpnext
nginx -t && systemctl reload nginx

echo "🔐 Getting Let's Encrypt SSL..."
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

echo "✅ ERPNext installed at: https://$DOMAIN"
