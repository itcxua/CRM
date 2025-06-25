#!/bin/bash
# EspoCRM Installer for Ubuntu 22.04 with Nginx + PHP + MariaDB + Let's Encrypt SSL
# Usage: chmod +x install_espocrm.sh && sudo ./install_espocrm.sh crm.it.cx.ua
#
# 🧾 Параметри підключення:
# DB Name: espocrm
# DB User: espouser
# PASSWORD: espopass
#
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
apt install -y nginx mariadb-server php php-cli php-fpm php-mysql php-xml         php-mbstring php-curl php-zip php-gd php-intl unzip curl wget certbot         php-bcmath php-soap php-imap php-readline php-opcache php-common         php-tokenizer php-dom php-mysqli php-fileinfo php-json php-xmlreader         php-xmlwriter php-phar php-posix php-simplexml php-sockets php-exif         php-pdo php-calendar php-ctype php-iconv php-gettext php-session         php-sysvsem php-zlib php-mbstring php-bz2 php-gmp php-ldap         php-openssl php-pdo-mysql php-pdo-sqlite php-shmop php-sysvmsg         php-sysvshm -y

echo "🐘 Setting up MariaDB..."
systemctl enable mariadb
systemctl start mariadb
DB_PASS="espopass"
mysql -u root <<EOF
CREATE DATABASE espocrm CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'espouser'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON espocrm.* TO 'espouser'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "📁 Downloading EspoCRM..."
cd /var/www/
wget https://www.espocrm.com/downloads/EspoCRM-7.5.6.zip
unzip EspoCRM-7.5.6.zip
mv EspoCRM-7.5.6 espocrm
chown -R www-data:www-data /var/www/espocrm
chmod -R 755 /var/www/espocrm

echo "🌐 Configuring Nginx..."
cat <<EOF > /etc/nginx/sites-available/espocrm
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/espocrm;
    index index.php index.html index.htm;

    location / {
        try_files \$uri /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires max;
        log_not_found off;
    }
}
EOF

ln -s /etc/nginx/sites-available/espocrm /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo "🔐 Getting Let's Encrypt SSL..."
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

echo "✅ EspoCRM installed at: https://$DOMAIN"
echo "🧾 DB Name: espocrm | User: espouser | Password: $DB_PASS"
