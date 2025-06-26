#!/bin/bash

# ERPNext 14+ install script with menu, IP detection, domain prompt,
# password generation, and .env output.
# Author: itcxua
# Version: 2.1

set -e  # Завершити скрипт при першій помилці

# Генерація випадкового пароля певної довжини з вказаного набору символів
gen_passwd() {
  tr -dc "$2" < /dev/urandom | head -c "$1"
}

# Забезпечити наявність директорії, створити її за потреби
ensure_directory() {
  if ! mkdir -p "$1" 2>/dev/null; then
    echo "❌ Error: Failed to create or access $1 directory."
    exit 1
  fi
}

# Перевірка відкритості портів 80 або 443 (для SSL)
check_ports() {
  ss -tuln | grep -q ':80\|:443'
}

# Отримання IP-адреси сервера
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Запит домену, за замовчуванням використовується IP, якщо домен не вказаний або некоректний
echo "🌐 Enter domain name (leave empty to use IP: $IP_ADDRESS):"
read -p "Domain: " DOMAIN
if [[ -n "$DOMAIN" && ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  echo "❌ Invalid domain format. Falling back to IP: $IP_ADDRESS"
  DOMAIN="$IP_ADDRESS"
else
  DOMAIN=${DOMAIN:-$IP_ADDRESS}
fi

# Вибір або введення email-адреси
default_email="admin@$DOMAIN"
echo "📧 Do you want to use default email ($default_email)? [Y/n]"
read -p "Answer: " email_choice
if [[ "$email_choice" =~ ^([nN])$ ]]; then
  read -p "Enter your email: " EMAIL
else
  EMAIL="$default_email"
fi

# Генерація паролів для бази даних та адміністратора ERPNext
DB_PASS=$(gen_passwd $(shuf -i 25-29 -n 1) 'a-zA-Z0-9')
ADMIN_PASS=$(gen_passwd $(shuf -i 20-25 -n 1) 'a-zA-Z0-9')

# Створення директорії для збереження конфігурації
echo "📁 Creating /opt directory if it does not exist..."
ensure_directory /opt

# Запис параметрів до .env файлу
cat <<EOF > /opt/erpnext_install.env
DOMAIN=$DOMAIN
IP_ADDRESS=$IP_ADDRESS
EMAIL=$EMAIL
DB_PASS=$DB_PASS
ADMIN_PASS=$ADMIN_PASS
EOF

# Оновлення системних пакетів
echo "📦 Updating system..."
apt update && apt upgrade -y

# Встановлення всіх необхідних залежностей
echo "🧰 Installing dependencies..."
DEPENDENCIES=(
  python3-dev python3-setuptools python3-pip python3-distutils
  redis-server mariadb-server mariadb-client software-properties-common
  nginx curl supervisor certbot python3-certbot-nginx git xvfb
  libfontconfig wkhtmltopdf libxrender1 libxext6 libxrandr2 libfreetype6
  libx11-6 libxcomposite1 libxcursor1 libxdamage1 libxi6 libxtst6
  libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libdbus-1-3
)
apt install -y "${DEPENDENCIES[@]}"

# Встановлення Node.js 16
echo "🧰 Installing Node.js 16 LTS..."
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt install -y nodejs

# Налаштування MariaDB для ERPNext
echo "🐘 Configuring MariaDB..."
systemctl enable mariadb
systemctl start mariadb

# Перевірка підключення до БД
if ! mysqladmin ping -u root --silent; then
  echo "❌ Error: Unable to connect to MariaDB as root."
  exit 1
fi

# Виконання необхідних налаштувань MariaDB
mysql -u root <<EOF
SET GLOBAL innodb_file_format = BARRACUDA;
SET GLOBAL innodb_file_per_table = ON;
SET GLOBAL innodb_large_prefix = ON;
CREATE DATABASE IF NOT EXISTS erpnext;
EOF

# Встановлення інструменту Bench
echo "🔧 Installing bench CLI..."
if ! pip3 install frappe-bench; then
  echo "❌ Failed to install frappe-bench. Consider checking pip or using virtualenv."
  exit 1
fi

# Ініціалізація Bench та Frappe
echo "📁 Initializing bench & Frappe"
ensure_directory /opt/erpnext
cd /opt/erpnext

FRAPPE_BRANCH=version-14
if [ ! -d "frappe-bench" ]; then
  bench init frappe-bench --frappe-branch $FRAPPE_BRANCH
else
  echo "ℹ️ Bench already initialized. Skipping init."
fi
cd frappe-bench

# Завантаження ERPNext як застосунку
echo "📦 Getting ERPNext app..."
if [ ! -d apps/erpnext ]; then
  bench get-app erpnext --branch $FRAPPE_BRANCH
else
  echo "ℹ️ ERPNext app already present. Skipping get-app."
fi

# Створення сайту та встановлення ERPNext
if ! bench new-site "$DOMAIN" --admin-password "$ADMIN_PASS" --mariadb-root-password "$DB_PASS"; then
  echo "❌ Failed to create new ERPNext site. Please check MariaDB password or logs."
  exit 1
fi

if ! bench --site "$DOMAIN" install-app erpnext; then
  echo "❌ Failed to install ERPNext app."
  exit 1
fi

# Перехід до production-режиму, якщо ще не налаштовано
echo "🔁 Setting up production environment..."
if ! supervisorctl status | grep -q "frappe-bench-web"; then
  bench setup production $(whoami) --yes
else
  echo "✅ Production mode already configured. Skipping setup."
fi

# Налаштування Nginx reverse proxy
echo "🌐 Configuring Nginx..."
bench setup nginx
NGINX_CONF_PATH="$(pwd)/config/nginx.conf"
if [ -f "$NGINX_CONF_PATH" ]; then
  if [ -L /etc/nginx/sites-enabled/erpnext ]; then
    echo "🔁 Nginx symlink already exists. Updating..."
  fi
  ln -sf "$NGINX_CONF_PATH" /etc/nginx/sites-enabled/erpnext
else
  echo "❌ Nginx config not found at $NGINX_CONF_PATH."
  exit 1
fi
nginx -t && systemctl reload nginx

# Отримання SSL-сертифіката
echo "🔐 Obtaining SSL certificate..."
if ! certbot certificates | grep -q "Domains: $DOMAIN"; then
  if ! check_ports; then
    echo "❌ Error: Required ports 80 or 443 are not open. Please check firewall or network settings."
    exit 1
  fi
  certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL
  echo "📁 SSL directory: /etc/letsencrypt/live/$DOMAIN" >> /opt/erpnext_install.env
else
  echo "🔐 SSL already exists for $DOMAIN. Skipping issuance."
fi

# Завершення установки та виведення результатів
echo "✅ ERPNext successfully installed!"
echo "============================================="
echo "🔗 Access: https://$DOMAIN"
echo "📄 .env saved to: /opt/erpnext_install.env"
echo "📧 Email used: $EMAIL"
echo "🔐 DB Password: $DB_PASS"
echo "🔐 Admin Password: $ADMIN_PASS"
echo "🔐 SSL path: /etc/letsencrypt/live/$DOMAIN"
echo "============================================="
