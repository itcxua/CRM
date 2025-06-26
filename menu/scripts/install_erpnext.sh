#!/bin/bash

# ERPNext 14+ install script with menu, IP detection, domain prompt,
# password generation, and .env output.
# Author: itcxua
# Version: 2.1

set -e  # Завершити скрипт при першій помилці

# === Функція генерації безпечного випадкового пароля ===
gen_passwd() {
  local length=$1  # довжина пароля
  local charset="$2"  # набір символів
  local max_attempts=${3:-5}  # максимальна кількість спроб, за замовчуванням 5
  local password=""
  local attempts=0

  while [ ${#password} -lt "$length" ] && [ $attempts -lt $max_attempts ]; do
    password=$(echo "$password""$(head -c 100 /dev/urandom | LC_ALL=C tr -dc "$charset")" | fold -w "$length" | head -n 1)
    attempts=$((attempts + 1))
  done

  if [ ${#password} -lt "$length" ]; then
    echo "❌ Error: Failed to generate secure password." >&2
    exit 1
  fi

  echo "$password"
}

# === Визначення основної IP-адреси сервера ===
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# === Запит домену (якщо не вказано — використовується IP) ===
echo "🌐 Enter domain name (leave empty to use IP: $IP_ADDRESS):"
read -p "Domain: " DOMAIN
# Перевірка базового формату домену (тільки якщо він не IP)
if [[ -n "$DOMAIN" && ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  echo "❌ Invalid domain format. Falling back to IP: $IP_ADDRESS"
  DOMAIN="$IP_ADDRESS"
else
  DOMAIN=${DOMAIN:-$IP_ADDRESS}
fi

# === Запит email-адреси (або використання за замовчуванням) ===
default_email="admin@$DOMAIN"
echo "📧 Do you want to use default email ($default_email)? [Y/n]"
read -p "Answer: " email_choice
if [[ "$email_choice" =~ ^([nN])$ ]]; then
  read -p "Enter your email: " EMAIL
else
  EMAIL="$default_email"
fi

# === Генерація паролів для бази та адміністратора ===
SHUF=$(shuf -i 25-29 -n 1)  # випадкова довжина пароля
DB_PASS=$(gen_passwd "$SHUF" "a-zA-Z0-9")
ADMIN_PASS=$(gen_passwd 12 "a-zA-Z0-9")

# === Перевірка/створення директорії для збереження .env ===
mkdir -p /opt

# === Збереження конфігурації в .env файл ===
cat <<EOF > /opt/erpnext_install.env
DOMAIN=$DOMAIN
IP_ADDRESS=$IP_ADDRESS
EMAIL=$EMAIL
DB_PASS=$DB_PASS
ADMIN_PASS=$ADMIN_PASS
EOF

# === Оновлення системи ===
echo "📦 Updating system..."
apt update && apt upgrade -y

# === Встановлення залежностей ===
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

# === Встановлення Node.js 16 LTS ===
echo "🧰 Installing Node.js 16 LTS..."
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt install -y nodejs

# === Налаштування MariaDB для ERPNext ===
echo "🐘 Configuring MariaDB..."
systemctl enable mariadb
systemctl start mariadb

# Перевірка підключення до MariaDB
if ! mysqladmin ping -u root --silent; then
  echo "❌ Error: Unable to connect to MariaDB as root."
  exit 1
fi

mysql -u root <<EOF
SET GLOBAL innodb_file_format = BARRACUDA;
SET GLOBAL innodb_file_per_table = ON;
SET GLOBAL innodb_large_prefix = ON;
CREATE DATABASE IF NOT EXISTS erpnext;
EOF

# === Встановлення Bench CLI ===
echo "🔧 Installing bench CLI..."
if ! pip3 install frappe-bench; then
  echo "❌ Failed to install frappe-bench. Consider checking pip or using virtualenv."
  exit 1
fi

# === Ініціалізація Bench та Frappe ===
echo "📁 Initializing bench & Frappe"
mkdir -p /opt/erpnext
cd /opt/erpnext

FRAPPE_BRANCH=version-14
bench init frappe-bench --frappe-branch $FRAPPE_BRANCH
cd frappe-bench

# === Завантаження ERPNext та створення сайту ===
echo "📦 Getting ERPNext app..."
bench get-app erpnext --branch $FRAPPE_BRANCH

# Обробка помилок створення сайту
if ! bench new-site "$DOMAIN" --admin-password "$ADMIN_PASS" --mariadb-root-password "$DB_PASS"; then
  echo "❌ Failed to create new ERPNext site. Please check MariaDB password or logs."
  exit 1
fi

# Обробка помилок установки ERPNext додатку
if ! bench --site "$DOMAIN" install-app erpnext; then
  echo "❌ Failed to install ERPNext app."
  exit 1
fi

# === Перехід до production режиму ===
echo "🔁 Setting up production environment..."
if ! supervisorctl status | grep -q "frappe-bench-web"; then
  bench setup production $(whoami) --yes
else
  echo "✅ Production mode already configured. Skipping setup."
fi

# === Налаштування Nginx ===
echo "🌐 Configuring Nginx..."
bench setup nginx
ln -s `pwd`/config/nginx.conf /etc/nginx/sites-enabled/erpnext
nginx -t && systemctl reload nginx

# === Отримання SSL-сертифіката від Let's Encrypt ===
echo "🔐 Obtaining SSL certificate..."
if ! certbot certificates | grep -q "Domains: $DOMAIN"; then
  certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL
  echo "📁 SSL directory: /etc/letsencrypt/live/$DOMAIN" >> /opt/erpnext_install.env
else
  echo "🔐 SSL already exists for $DOMAIN. Skipping issuance."
fi

# === Завершення: виведення даних доступу ===
echo "✅ ERPNext successfully installed!"
echo "============================================="
echo "🔗 Access: https://$DOMAIN"
echo "📄 .env saved to: /opt/erpnext_install.env"
echo "📧 Email used: $EMAIL"
echo "🔐 DB Password: $DB_PASS"
echo "🔐 Admin Password: $ADMIN_PASS"
echo "🔐 SSL path: /etc/letsencrypt/live/$DOMAIN"
echo "============================================="
