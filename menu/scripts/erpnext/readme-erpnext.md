# 📦 ERPNext Installation Script (Multiversion, CLI-ready, Telegram & FTP)

Автоматизований скрипт для встановлення ERPNext (v14, v15, develop) з підтримкою:
- Вибору гілки (branch)
- Встановлення залежностей (Node.js, Python)
- Генерації/CLI-паролів
- Створення `.env`
- DRY-RUN режиму
- Надсилання результатів у Telegram або через FTP
- Логування в `/opt/erpnext_installer.log`

---

## 🧰 Вимоги
- Ubuntu 20.04 / 22.04 (root доступ)
- `curl`, `ss`, `certbot`, `nginx`, `MariaDB`, `Python 3.10+`

---

## ⚙️ Запуск

### 🔹 Інтерактивно:
```bash
bash MainMenu.sh
```

### 🔹 Через CLI (повністю автоматично):
```bash
bash install_erpnext_menu.sh \
  --branch=version-15 \
  --domain=demo.example.com \
  --email=admin@example.com \
  --admin-pass=MySecret123 \
  --db-pass=DBpass456 \
  --push-env=telegram \
  --dry-run
```

---

## 📂 Структура
```
crm-installer/
├── MainMenu.sh
├── config.yaml               # fallback config
└── scripts/
    ├── install_erpnext_menu.sh
    ├── install_node_python.sh
```

---

## 🔐 Аргументи CLI
| Параметр         | Опис                                  |
|------------------|-----------------------------------------|
| `--branch`       | `version-14` / `version-15` / `develop` |
| `--domain`       | Домен або IP                            |
| `--email`        | Email для SSL                           |
| `--admin-pass`   | Пароль адміністратора ERP               |
| `--db-pass`      | Пароль MariaDB                          |
| `--dry-run`      | Лише симуляція, без встановлення        |
| `--push-env`     | `telegram` / `ftp` / `none`             |
| `--ftp-url`      | FTP шлях для завантаження `.env`        |

---

## 📤 Надсилання результатів

- **Telegram:** автоматично через API.
- **FTP:** використовується `curl -T <file> <ftp-url>`.
- **.env:** зберігається у `/opt/erpnext_install.env`.

---

## 📝 Логи

- `/opt/erpnext_installer.log` — усі ключові параметри запуску, статуси, CLI-джерела паролів.

---

## ✅ Особливості
- Автогенерація паролів з `urandom`
- Валідація введених значень (email, domain, branch)
- Перевірка портів 80/443
- Підтримка production режиму (`bench setup production`)

---

## 🧪 Приклад Telegram-повідомлення:
```
🔐 ERPNext install:
🌐 https://demo.example.com
📧 admin@example.com
DB: ••••••••••
ADMIN: •••••••••
```

---

## 📦 Ліцензія
MIT — без обмежень, можна модифікувати та використовувати.

---

> Розроблено з ❤️ для автоматизації ERP-встановлення | @itcxua
