#!/bin/bash

# ▓▓▓ CONFIG ▓▓▓
DOMAIN="suitecrm.it.cx.ua"
ADMIN_NAME="admin"
ADMIN_PASS="StrongAdminPass123!"
ADMIN_EMAIL="admin@$DOMAIN"
DB_NAME="suitecrm"
DB_USER="suitecrm_user"
DB_PASS="StrongDBpass456!"
HOSTNAME="suitecrm-nginx"
PHP_VERSION="8.1"

# ▓▓▓ SYSTEM ▓▓▓
echo "[1/8] Оновлення системи..."
apt update && apt upgrade -y

echo "[2/8] Встановлення пакетів..."
apt install -y nginx mariadb-server unzip curl php$PHP_VERSION-fpm \
 php$PHP_VERSION-{cli,common,curl,mbstring,gd,mysql,xml,bcmath,zip,intl} \
 certbot python3-certbot-nginx

# ▓▓▓ DATABASE ▓▓▓
echo "[3/8] Створення БД..."
mysql -u root <<EOF
CREATE DATABASE $DB_NAME CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# ▓▓▓ SUITECRM ▓▓▓
echo "[4/8] Завантаження SuiteCRM..."
cd /var/www/
curl -L -o suitecrm.zip https://suitecrm.com/files/162/SuiteCRM-8-2/742/SuiteCRM-8.2.4.zip
unzip suitecrm.zip
rm suitecrm.zip
mv SuiteCRM-8* suitecrm
chown -R www-data:www-data suitecrm
chmod -R 755 suitecrm

# ▓▓▓ NGINX ▓▓▓
echo "[5/8] Налаштування NGINX..."
cat <<EOF > /etc/nginx/sites-available/$DOMAIN
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/suitecrm/public;
    index index.php index.html;

    access_log /var/log/nginx/suitecrm_access.log;
    error_log /var/log/nginx/suitecrm_error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# ▓▓▓ SSL ▓▓▓
echo "[6/8] SSL через Let's Encrypt..."
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $ADMIN_EMAIL

# ▓▓▓ HOSTNAME ▓▓▓
echo "[7/8] Хостнейм..."
hostnamectl set-hostname $HOSTNAME
echo "127.0.1.1 $HOSTNAME.$DOMAIN $HOSTNAME" >> /etc/hosts

# ▓▓▓ Права ▓▓▓
echo "[8/8] Завершальні налаштування..."
cd /var/www/suitecrm
chown -R www-data:www-data .
chmod -R 755 .

# ▓▓▓ DONE ▓▓▓
echo "✅ Установка SuiteCRM завершена. Відкрий у браузері: https://$DOMAIN"
echo "➤ Встанови SuiteCRM через веб-інтерфейс, використовуючи:"
echo "   - DB Name: $DB_NAME"
echo "   - DB User: $DB_USER"
echo "   - DB Pass: $DB_PASS"
