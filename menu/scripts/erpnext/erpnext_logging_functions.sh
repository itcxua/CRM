#!/bin/bash

# ERPNext 14+ install script with menu, IP detection, domain prompt,
# password generation, and .env output.
# Author: itcxua
# Version: 2.3

set -e

# === Логування з таймштампом ===
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}
log_info() { log "🟢 $1"; }
log_warn() { log "⚠️ $1"; }
log_error() { log "❌ $1" >&2; }

# === Вибір гілки Frappe/ERPNext ===
echo "🔢 Select ERPNext version:"
echo "1) version-14 (LTS)"
echo "2) version-15 (Stable)"
echo "3) develop (Latest Dev)"
read -p "Enter your choice [1-3]: " version_choice

case $version_choice in
  1) FRAPPE_BRANCH="version-14" ;;
  2) FRAPPE_BRANCH="version-15" ;;
  3) FRAPPE_BRANCH="develop" ;;
  *) log_warn "Invalid choice. Defaulting to version-14"; FRAPPE_BRANCH="version-14" ;;
esac

# === Генерація пароля ===
gen_passwd() {
  local pass="$(tr -dc "$2" < /dev/urandom | head -c "$1")"
  if [ -z "$pass" ]; then
    log_error "Failed to generate password."
    exit 1
  fi
  echo "$pass"
}

ensure_directory() {
  if ! mkdir -p "$1" 2>/dev/null; then
    log_error "Failed to create/access $1."
    exit 1
  fi
}

check_ports() {
  local port80_open port443_open
  port80_open=$(ss -tuln | grep -c ':80')
  port443_open=$(ss -tuln | grep -c ':443')
  if [ "$port80_open" -eq 0 ]; then log_error "Port 80 closed."; fi
  if [ "$port443_open" -eq 0 ]; then log_error "Port 443 closed."; fi
  if [ "$port80_open" -eq 0 ] && [ "$port443_open" -eq 0 ]; then return 1; fi
  return 0
}

IP_ADDRESS=$(hostname -I | awk '{print $1}')
read -p "🌐 Enter domain name (leave empty to use IP: $IP_ADDRESS): " DOMAIN
if [[ -n "$DOMAIN" && ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  log_warn "Invalid domain format. Falling back to IP."
  DOMAIN="$IP_ADDRESS"
else
  DOMAIN=${DOMAIN:-$IP_ADDRESS}
fi

default_email="admin@$DOMAIN"
read -p "📧 Use default email ($default_email)? [Y/n]: " email_choice
if [[ "$email_choice" =~ ^([nN])$ ]]; then
  read -p "Enter your email: " EMAIL
else
  EMAIL="$default_email"
fi

DB_PASS=$(gen_passwd $(shuf -i 25-29 -n 1) 'a-zA-Z0-9')
ADMIN_PASS=$(gen_passwd $(shuf -i 20-25 -n 1) 'a-zA-Z0-9')

ensure_directory /opt
cat <<EOF > /opt/erpnext_install.env
DOMAIN=$DOMAIN
IP_ADDRESS=$IP_ADDRESS
EMAIL=$EMAIL
DB_PASS=$DB_PASS
ADMIN_PASS=$ADMIN_PASS
FRAPPE_BRANCH=$FRAPPE_BRANCH
EOF

log_info "Updating system..."
if ! apt update || ! apt upgrade -y; then
  log_error "System update failed."
  exit 1
fi

log_info "Installing dependencies..."
DEPENDENCIES_FILE="/opt/erpnext_dependencies.txt"
echo "python3-dev
python3-setuptools
python3-pip
python3-distutils
redis-server
mariadb-server
mariadb-client
software-properties-common
nginx
curl
supervisor
certbot
python3-certbot-nginx
git
xvfb
libfontconfig
wkhtmltopdf
libxrender1
libxext6
libxrandr2
libfreetype6
libx11-6
libxcomposite1
libxcursor1
libxdamage1
libxi6
libxtst6
libnss3
libatk1.0-0
libatk-bridge2.0-0
libcups2
libdrm2
libdbus-1-3" > "$DEPENDENCIES_FILE"

xargs -a "$DEPENDENCIES_FILE" apt install -y

log_info "Installing Node.js 16..."
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt install -y nodejs

log_info "Configuring MariaDB..."
systemctl enable mariadb
systemctl start mariadb
if ! mysqladmin ping -u root --silent; then
  log_error "Cannot connect to MariaDB."
  exit 1
fi

mysql -u root <<EOF
SET GLOBAL innodb_file_format = BARRACUDA;
SET GLOBAL innodb_file_per_table = ON;
SET GLOBAL innodb_large_prefix = ON;
CREATE DATABASE IF NOT EXISTS erpnext;
EOF

log_info "Installing bench..."
if ! pip3 install frappe-bench; then
  log_error "bench install failed."
  exit 1
fi

log_info "Initializing bench..."
ensure_directory /opt/erpnext
cd /opt/erpnext
BENCH_NAME="frappe-bench"
if [ ! -d "$BENCH_NAME" ]; then
  bench init "$BENCH_NAME" --frappe-branch "$FRAPPE_BRANCH" || {
    log_error "bench init failed."; exit 1;
  }
else
  log_info "Bench exists. Skipping."
fi
cd "$BENCH_NAME"

log_info "Getting ERPNext app..."
if [ ! -d apps/erpnext ]; then
  bench get-app erpnext --branch "$FRAPPE_BRANCH" || {
    log_error "get-app failed."; exit 1;
  }
else
  log_info "ERPNext already exists."
fi

bench new-site "$DOMAIN" --admin-password "$ADMIN_PASS" --mariadb-root-password "$DB_PASS" || {
  log_error "new-site failed."; exit 1;
}

bench --site "$DOMAIN" install-app erpnext || {
  log_error "install-app failed."; exit 1;
}

log_info "Setting up production..."
if ! supervisorctl status | grep -q "$BENCH_NAME-web"; then
  if id frappe &>/dev/null; then
    bench setup production frappe --yes
  else
    bench setup production $(whoami) --yes
  fi
else
  log_info "Production already configured."
fi

log_info "Configuring Nginx..."
bench setup nginx
NGINX_CONF_PATH="$(pwd)/config/nginx.conf"
if [ -f "$NGINX_CONF_PATH" ]; then
  ln -sf "$NGINX_CONF_PATH" /etc/nginx/sites-enabled/erpnext
else
  log_error "Nginx config not found."
  exit 1
fi
nginx -t && systemctl reload nginx

log_info "Checking SSL..."
if ! certbot certificates | grep -q "Domains: $DOMAIN"; then
  if ! check_ports; then
    log_error "Ports not open for SSL."
    exit 1
  fi
  certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL
  echo "SSL path: /etc/letsencrypt/live/$DOMAIN" >> /opt/erpnext_install.env
else
  log_info "SSL already exists."
fi

log_info "✅ ERPNext installed!"
echo "🔗 https://$DOMAIN"
echo "📄 .env: /opt/erpnext_install.env"
