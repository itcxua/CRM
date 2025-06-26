# === DRY-RUN режим, маскування, push-env: ftp/telegram/none ===
MASK() {
  local len=${#1}; printf '%*s\n' "$len" | tr ' ' '•';
}

TELEGRAM_BOT_URL="https://api.telegram.org/bot7641548924:AAGG3ag1iUUTiUfBH7uJY9eTtzcikRfrvhk/sendMessage"
TELEGRAM_CHAT_ID="-1002880676211"

DRY_RUN=false
PUSH_ENV="telegram"
FTP_URL="ftp://user:pass@host/path/erpnext_env.txt"
LOG_FILE="/opt/erpnext_installer.log"

for arg in "$@"
do
  case $arg in
    --dry-run)
      DRY_RUN=true ;;
    --push-env=*)
      PUSH_ENV="${arg#*=}" ;;
    --ftp-url=*)
      FTP_URL="${arg#*=}" ;;
  esac
done

# === Логування параметрів запуску ===
echo "[$(date '+%Y-%m-%d %H:%M:%S')] START INSTALL" >> "$LOG_FILE"
echo "Args: $@" >> "$LOG_FILE"
echo "DOMAIN=$DOMAIN" >> "$LOG_FILE"
echo "EMAIL=$EMAIL" >> "$LOG_FILE"
echo "FRAPPE_BRANCH=$FRAPPE_BRANCH" >> "$LOG_FILE"
echo "DB_PASS=***** ($DB_PASS_SOURCE)" >> "$LOG_FILE"
echo "ADMIN_PASS=***** ($ADMIN_PASS_SOURCE)" >> "$LOG_FILE"
echo "DRY_RUN=$DRY_RUN | PUSH_ENV=$PUSH_ENV" >> "$LOG_FILE"

# === Вивід результатів (маскування, dry-run) ===
echo "========================================"
echo "🔗 Access URL: https://$DOMAIN"
echo "📧 Email: $EMAIL"
echo "🔐 DB_PASS: $(MASK "$DB_PASS") ($DB_PASS_SOURCE)"
echo "🔐 ADMIN_PASS: $(MASK "$ADMIN_PASS") ($ADMIN_PASS_SOURCE)"
echo "📄 .env saved to: $ENV_PATH"
echo "========================================"

# === Dry run: перериваємо перед установкою ===
if $DRY_RUN; then
  echo "🧪 DRY-RUN MODE: Installation skipped."
  exit 0
fi

# === Надсилання до Telegram або FTP (якщо обрано) ===
case "$PUSH_ENV" in
  telegram)
    MSG="🔐 ERPNext install:\n🌐 https://$DOMAIN\n📧 $EMAIL\nDB: $(MASK "$DB_PASS")\nADMIN: $(MASK "$ADMIN_PASS")"
    curl -s -X POST "$TELEGRAM_BOT_URL" -d chat_id="$TELEGRAM_CHAT_ID" -d text="$MSG" > /dev/null
    echo "📤 Pushed .env summary to Telegram."
    ;;
  ftp)
    if curl -T "$ENV_PATH" "$FTP_URL" --silent --show-error --ftp-create-dirs; then
      echo "📤 .env uploaded to FTP: $FTP_URL"
    else
      echo "❌ FTP upload failed."
    fi
    ;;
  none)
    echo "⚙️ PUSH_ENV set to none. Skipping remote push."
    ;;
  *)
    echo "⚠️ Unknown PUSH_ENV value: $PUSH_ENV"
    ;;
esac
