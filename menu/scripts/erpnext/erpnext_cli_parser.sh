# === Обробка аргументів CLI з пріоритетом ===
for arg in "$@"
do
  case $arg in
    --branch=*) FRAPPE_BRANCH="${arg#*=}" ;;
    --domain=*) DOMAIN="${arg#*=}" ;;
    --email=*)  EMAIL="${arg#*=}" ;;
    --admin-pass=*) ADMIN_PASS="${arg#*=}" ;;
    --db-pass=*) DB_PASS="${arg#*=}" ;;
    *) echo "⚠️ Unknown argument: $arg" ;;
  esac
done

# === Валідація значень ===
# Перевірка гілки
if [[ -n "$FRAPPE_BRANCH" && ! "$FRAPPE_BRANCH" =~ ^(version-14|version-15|develop)$ ]]; then
  echo "❌ Invalid branch: $FRAPPE_BRANCH. Must be version-14, version-15, or develop."; exit 1
fi

# Перевірка домену (мінімальна)
if [[ -n "$DOMAIN" && ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  echo "❌ Invalid domain format: $DOMAIN"; exit 1
fi

# Перевірка email
if [[ -n "$EMAIL" && ! "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
  echo "❌ Invalid email format: $EMAIL"; exit 1
fi
