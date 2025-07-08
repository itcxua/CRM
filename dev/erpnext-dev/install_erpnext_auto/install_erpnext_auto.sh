#!/bin/bash

# ERPNext installer with domain validation and credential storage
# Author: ITcxUA | Version: 1.1 | Ubuntu 22.04 LTS

set -e

### === ФУНКЦІЯ: Генерація пароля (без спецсимволів) ===
generate_password() {
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
}

### === ФУНКЦІЯ: Перевірка домену ===
validate_domain() {
  local domain=$1
  if [[ "$domain" =~ ^([a-zA-Z0-9](-?[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}$ ]]; then
    return 0
  else
    return 1
  fi
}

### === ВВЕДЕННЯ ДОМЕНУ ===
MAX_ATTEMPTS=2
attempt=0
domain_input=""

while [ $attempt -le $MAX_ATTEMPTS ]; do
  read -rp "Введіть домен для ERPNext (наприклад, erp.example.com): " domain_input
  if validate_domain "$domain_input"; then
    domain="$domain_input"
    break
  else
    echo "❌ Невірний формат домену."
    attempt=$((attempt + 1))
  fi
done

if [ -z "$domain" ]; then
  domain=$(hostname -I | awk '{print $1}')
  echo "⚠️ Використовується IP адреса сервера як домен: $domain"
fi

echo "✅ Обраний домен/IP: $domain"

### === ЗГЕНЕРУВАТИ ПАРОЛІ ===
MYSQL_ROOT_PWD=$(generate_password)
ERP_ADMIN_PWD=$(generate_password)
MYSQL_USER="erpuser_$(head /dev/urandom | tr -dc a-z0-9 | head -c 5)"
MYSQL_USER_PWD=$(generate_password)

### === ЗБЕРЕЖЕННЯ ПАРОЛІВ ===
ENV_FILE="$HOME/erpnext-credentials.env"
echo "🌐 Збереження паролів у $ENV_FILE"

cat > "$ENV_FILE" <<EOF
# === ERPNext Установочні Дані ===
DOMAIN=$domain

# === MySQL ===
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PWD
MYSQL_USER=$MYSQL_USER
MYSQL_USER_PASSWORD=$MYSQL_USER_PWD

# === ERPNext Admin ===
ERP_ADMIN_PASSWORD=$ERP_ADMIN_PWD
EOF

chmod 600 "$ENV_FILE"

### === СИСТЕМНА ПІДГОТОВКА ===
echo "🔧 Оновлення системи..."
sudo apt update && sudo apt upgrade -y

echo "📦 Встановлення залежностей..."
sudo apt install -y python3-dev python3-pip python3-setuptools python3-venv \
  mariadb-server redis-server nginx curl git software-properties-common \
  xvfb libfontconfig wkhtmltopdf libmysqlclient-dev

### === NODE.js 18 ===
echo "⚙️ Встановлення Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
npm install -g yarn

### === FRAPPE-BENCH ===
sudo pip3 install frappe-bench

### === НАЛАШТУВАННЯ MARIADB ===
echo "🔑 Налаштування MariaDB..."
sudo systemctl enable mariadb
sudo systemctl start mariadb

sudo mysql -u root <<MYSQL_SCRIPT
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PWD';
CREATE USER '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_USER_PWD';
GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

### === СТВОРЕННЯ BENCH ===
bench init erpnext --frappe-branch version-15
cd erpnext

### === СТВОРЕННЯ САЙТУ ===
bench new-site "$domain" \
  --admin-password "$ERP_ADMIN_PWD" \
  --mariadb-root-password "$MYSQL_ROOT_PWD"

### === ERPNext ===
bench get-app erpnext --branch version-15
bench --site "$domain" install-app erpnext

### === ПРОДАКШН ===
bench setup production $(whoami) --yes

echo -e "\n✅ Установка завершена."
echo "🌍 Доступ до ERPNext: http://$domain"
echo "🔐 Паролі збережено в: $ENV_FILE"

echo -e "\n🧾 Вміст збережених даних:"
cat "$ENV_FILE"
