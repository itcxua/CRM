Ось повний набір файлів, які будуть включені до архіву `install_erpnext_auto.tar.gz`.

---

## 📁 Структура архіву:

```
install_erpnext_auto/
├── install_erpnext_auto.sh       ← головний bash-скрипт
├── .env.template                 ← шаблон змінних середовища
├── README.md                     ← інструкція
```

---

## 📜 1. `install_erpnext_auto/install_erpnext_auto.sh`


---

## 📜 2. `install_erpnext_auto/.env.template`

```env
# === ERPNext Установочні Дані ===
DOMAIN=erp.example.com

# === MySQL ===
MYSQL_ROOT_PASSWORD=your_root_pwd_here
MYSQL_USER=erpuser_xxxxx
MYSQL_USER_PASSWORD=your_user_pwd_here

# === ERPNext Admin ===
ERP_ADMIN_PASSWORD=your_admin_pwd_here
```


## 🔧 Інструкція

1. Скачайте архів і розпакуйте:
```bash
mkdir cd $HOME/install_erpnext_auto && cd $HOME/cd install_erpnext_auto;
wget https://raw.githubusercontent.com/itcxua/CRM/refs/heads/main/dev/erpnext-dev/install_erpnext_auto/install_erpnext_auto.sh;
chmod +x install_erpnext_auto.sh && ./install_erpnext_auto.sh;

```

3. Після завершення — паролі будуть збережені у:

```bash
~/erpnext-credentials.env
```

---

## 🧾 Приклад .env

```
DOMAIN=erp.devolaris.com
MYSQL_ROOT_PASSWORD=Qwb2ZVR4Uz9NsqA1
MYSQL_USER=erpuser_f9qz2
MYSQL_USER_PASSWORD=Bv7q2Sd9MgErLpQw
ERP_ADMIN_PASSWORD=aB82deM6zp9vVmK1
```

> ⚠️ Не поширюйте файл `.env` публічно. Він містить чутливу інформацію.

---

## 📎 Потреби:

* Ubuntu 22.04 LTS
* 2+ CPU / 4+ GB RAM (рекомендовано)
* Права `sudo`

---

© ITcxUA

```
