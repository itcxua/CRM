#!/bin/bash
# Universal Odoo 17 Community Installer for Ubuntu 22.04 with Nginx + Let's Encrypt + Supervisor
# Usage: ./install_odoo17.sh yourdomain.com
# chmod +x install_odoo17.sh && sudo ./install_odoo17.sh crm.it.cx.ua
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
apt install -y git python3-pip build-essential wget python3-dev python3-venv         libxslt-dev libzip-dev libldap2-dev libsasl2-dev libjpeg-dev libpq-dev         libxml2-dev libffi-dev libssl-dev node-less libjpeg8-dev liblcms2-dev         libblas-dev libatlas-base-dev python3-wheel nodejs npm curl nginx supervisor         certbot python3-certbot-nginx postgresql -y

echo "🐘 Configuring PostgreSQL..."
systemctl enable postgresql
systemctl start postgresql
su - postgres -c "createuser -s odoo" || true

echo "👤 Creating odoo system user..."
useradd -m -d /opt/odoo -U -r -s /bin/bash odoo || true

echo "📁 Cloning Odoo source..."
git clone https://www.github.com/odoo/odoo --depth 1 --branch 17.0 --single-branch /opt/odoo/odoo

echo "📦 Creating Python virtual environment..."
python3 -m venv /opt/odoo/venv
source /opt/odoo/venv/bin/activate
pip install wheel
pip install -r /opt/odoo/odoo/requirements.txt

echo "📁 Setting up addons path..."
mkdir -p /opt/odoo/custom/addons
chown -R odoo: /opt/odoo

echo "📝 Writing configuration..."
cat <<EOF > /etc/odoo.conf
[options]
admin_passwd = admin
db_host = False
db_port = False
db_user = odoo
db_password = False
addons_path = /opt/odoo/odoo/addons,/opt/odoo/custom/addons
logfile = /var/log/odoo/odoo.log
xmlrpc_port = 8069
EOF
chown odoo: /etc/odoo.conf
chmod 640 /etc/odoo.conf

echo "🔁 Configuring Supervisor..."
cat <<EOF > /etc/supervisor/conf.d/odoo.conf
[program:odoo]
command=/opt/odoo/venv/bin/python3 /opt/odoo/odoo/odoo-bin -c /etc/odoo.conf
autostart=true
autorestart=true
stderr_logfile=/var/log/odoo/err.log
stdout_logfile=/var/log/odoo/out.log
user=odoo
EOF

supervisorctl reread
supervisorctl update
supervisorctl start odoo

echo "🌐 Configuring Nginx..."
cat <<EOF > /etc/nginx/sites-available/odoo
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8069;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

echo "🔐 Setting up SSL with Let's Encrypt..."
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

echo "✅ Odoo installed at: https://$DOMAIN"
