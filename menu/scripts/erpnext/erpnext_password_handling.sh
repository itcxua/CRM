# === Генерація паролів або використання CLI-значень ===
# Генератор паролів
gen_passwd() {
  local pass="$(tr -dc "$2" < /dev/urandom | head -c "$1")"
  if [ -z "$pass" ]; then
    echo "❌ Failed to generate password."
    exit 1
  fi
  echo "$pass"
}

# Якщо не задано через CLI, згенерувати
if [ -z "$DB_PASS" ]; then
  DB_PASS=$(gen_passwd $(shuf -i 25-29 -n 1) 'a-zA-Z0-9')
  DB_PASS_SOURCE="generated"
else
  DB_PASS_SOURCE="cli"
fi

if [ -z "$ADMIN_PASS" ]; then
  ADMIN_PASS=$(gen_passwd $(shuf -i 20-25 -n 1) 'a-zA-Z0-9')
  ADMIN_PASS_SOURCE="generated"
else
  ADMIN_PASS_SOURCE="cli"
fi

# === Запис до .env ===
ENV_PATH="/opt/erpnext_install.env"
echo "DOMAIN=$DOMAIN" > "$ENV_PATH"
echo "IP_ADDRESS=$IP_ADDRESS" >> "$ENV_PATH"
echo "EMAIL=$EMAIL" >> "$ENV_PATH"
echo "FRAPPE_BRANCH=$FRAPPE_BRANCH" >> "$ENV_PATH"
echo -n "DB_PASS=$DB_PASS" >> "$ENV_PATH"
[ "$DB_PASS_SOURCE" = "cli" ] && echo "  # set via CLI" >> "$ENV_PATH" || echo >> "$ENV_PATH"
echo -n "ADMIN_PASS=$ADMIN_PASS" >> "$ENV_PATH"
[ "$ADMIN_PASS_SOURCE" = "cli" ] && echo "  # set via CLI" >> "$ENV_PATH" || echo >> "$ENV_PATH"

# === Вивід на екран після встановлення ===
echo "========================================"
echo "🔗 Access URL: https://$DOMAIN"
echo "📧 Email: $EMAIL"
echo "🔐 DB_PASS: $DB_PASS ($DB_PASS_SOURCE)"
echo "🔐 ADMIN_PASS: $ADMIN_PASS ($ADMIN_PASS_SOURCE)"
echo "📄 .env saved to: $ENV_PATH"
echo "========================================"
