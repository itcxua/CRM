#!/bin/bash
# Odoo 17 Community Edition install script for Ubuntu 22.04 + Nginx + SSL (Let's Encrypt)
# Domain: crm.it.cx.ua

set -e

DOMAIN="crm.it.cx.ua"
ADMIN_PASS="admin"
ODOO_PORT=8069
PG_VERSION=14

echo "📦 Updating system..."
apt update && apt upgrade -y

echo "🧰 Installing dependencies..."
apt install -y git python3-pip build-essential wget python3-dev python3-venv         libxslt-dev libzip-dev libldap2-dev libsasl2-dev libjpeg-dev libpq-dev         libxml2-dev libffi-dev libssl-dev node-less libjpeg8-dev liblcms2-dev         libblas-dev libatlas-base-dev python3-wheel nodejs npm curl

echo "🐘 Installing PostgreSQL..."
apt install postgresql -y
systemctl enable postgresql
systemctl start postgresql
su - postgres -c "createuser -s odoo" || true

echo "👤 Creating odoo system user..."
useradd -m -d /opt/odoo -U -r -s /bin/bash odoo || true

echo "📁 Cloning Odoo..."
mkdir -p /opt/odoo
git clone https://www.github.com/odoo/odoo --depth 1 --branch 17.0 --single-branch /opt/odoo/odoo

echo "📦 Creating virtual environment..."
python3 -m venv /opt/odoo/venv
source /opt/odoo/venv/bin/activate
pip install wheel
pip install -r /opt/odoo/odoo/requirements.txt

echo "📁 Creating custom addons folder..."
mkdir -p /opt/odoo/custom/addons
chown -R odoo: /opt/odoo

echo "📝 Creating Odoo configuration file..."
cat <<EOF > /etc/odoo.conf
[options]
admin_passwd = ${ADMIN_PASS}
db_host = False
db_port = False
db_user = odoo
db_password = False
addons_path = /opt/odoo/odoo/addons,/opt/odoo/custom/addons
logfile = /var/log/odoo/odoo.log
xmlrpc_port = ${ODOO_PORT}
EOF
chown odoo: /etc/odoo.conf
chmod 640 /etc/odoo.conf

echo "🔁 Setting up systemd service..."
cat <<EOF > /etc/systemd/system/odoo.service
[Unit]
Description=Odoo
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=odoo
Group=odoo
ExecStart=/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl enable odoo
systemctl start odoo

echo "🌐 Installing Nginx and Certbot..."
apt install -y nginx certbot python3-certbot-nginx

echo "🌍 Configuring Nginx reverse proxy..."
cat <<EOF > /etc/nginx/sites-available/odoo
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${ODOO_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo "🔐 Generating SSL certificate with Let's Encrypt..."
certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m admin@${DOMAIN}

echo "✅ Installation complete. Access Odoo at: https://${DOMAIN}"
