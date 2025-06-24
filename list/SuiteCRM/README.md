Ось повністю готовий **bash-скрипт для установки SuiteCRM "під ключ"** з урахуванням:

* Ubuntu 22.04 / 20.04
* Apache2
* PHP 7.4 / 8.1
* MySQL/MariaDB
* Домен: `suitecrm.it.cx.ua`
* Підтримка Let's Encrypt SSL
* Вказання імені хоста (hostname) + FQDN

---

### 📜 `install_suitecrm.sh`

```bash
#!/bin/bash

# ▓▓▓ CONFIG ▓▓▓
DOMAIN="suitecrm.it.cx.ua"
ADMIN_NAME="admin"
ADMIN_PASS="StrongAdminPass123!"
ADMIN_EMAIL="admin@$DOMAIN"
DB_NAME="suitecrm"
DB_USER="suitecrm_user"
DB_PASS="StrongDBpass456!"
HOSTNAME="suitecrm-host"
PHP_VERSION="8.1"

# ▓▓▓ SYSTEM ▓▓▓
echo "[1/8] Updating system..."
apt update && apt upgrade -y

echo "[2/8] Installing dependencies..."
apt install -y apache2 mariadb-server unzip curl php$PHP_VERSION php$PHP_VERSION-{cli,common,curl,mbstring,gd,mysql,xml,bcmath,zip,intl} certbot python3-certbot-apache

# ▓▓▓ DATABASE ▓▓▓
echo "[3/8] Creating MySQL database..."
mysql -u root <<EOF
CREATE DATABASE $DB_NAME CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# ▓▓▓ SUITECRM ▓▓▓
echo "[4/8] Downloading SuiteCRM..."
cd /var/www/
curl -L -o suitecrm.zip https://suitecrm.com/files/162/SuiteCRM-8-2/742/SuiteCRM-8.2.4.zip
unzip suitecrm.zip
rm suitecrm.zip
mv SuiteCRM-8* suitecrm
chown -R www-data:www-data suitecrm
chmod -R 755 suitecrm

# ▓▓▓ APACHE ▓▓▓
echo "[5/8] Configuring Apache..."
cat <<EOF > /etc/apache2/sites-available/$DOMAIN.conf
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot /var/www/suitecrm/public

    <Directory /var/www/suitecrm/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/suitecrm_error.log
    CustomLog \${APACHE_LOG_DIR}/suitecrm_access.log combined
</VirtualHost>
EOF

a2ensite $DOMAIN
a2enmod rewrite
a2dissite 000-default
systemctl reload apache2

# ▓▓▓ SSL ▓▓▓
echo "[6/8] Enabling HTTPS..."
certbot --apache -d $DOMAIN --non-interactive --agree-tos -m $ADMIN_EMAIL

# ▓▓▓ HOSTNAME ▓▓▓
echo "[7/8] Setting hostname..."
hostnamectl set-hostname $HOSTNAME
echo "127.0.1.1 $HOSTNAME.$DOMAIN $HOSTNAME" >> /etc/hosts

# ▓▓▓ PERMISSIONS ▓▓▓
echo "[8/8] Final permissions..."
cd /var/www/suitecrm
chown -R www-data:www-data .
chmod -R 755 .

# ▓▓▓ DONE ▓▓▓
echo "✅ Установка SuiteCRM завершена. Перейдіть на: https://$DOMAIN"
echo "➤ Встановіть SuiteCRM через веб-інтерфейс, використовуючи:"
echo "   - DB Name: $DB_NAME"
echo "   - DB User: $DB_USER"
echo "   - DB Pass: $DB_PASS"
```

---

### 🚀 Як використати:

1. Зберегти файл:

   ```bash
   nano install_suitecrm.sh
   chmod +x install_suitecrm.sh
   ```

2. Запустити:

   ```bash
   sudo ./install_suitecrm.sh
   ```

3. Перейти у браузері: [https://suitecrm.it.cx.ua](https://suitecrm.it.cx.ua)
   і пройти майстра установки, вказавши параметри БД.

---

### 🧩 Додатково:

* Після установки можна автоматизувати вхід через API або створити тестові модулі.
* За потреби —  **Ansible playbook**, **Docker версію**, або **MU-плагін для інтеграції з WordPress/CRM**.
