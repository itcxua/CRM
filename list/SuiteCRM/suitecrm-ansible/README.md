Ось **Ansible-плейбук для встановлення SuiteCRM з NGINX на Ubuntu 22.04**, що повністю відповідає bash-скрипту, який ми щойно створили.

---

## 📁 Структура проєкту Ansible

```
suitecrm-ansible/
├── inventory.ini
├── playbook.yml
└── roles/
    ├── common/
    │   └── tasks/main.yml
    ├── nginx/
    │   └── tasks/main.yml
    ├── mariadb/
    │   └── tasks/main.yml
    ├── suitecrm/
    │   └── tasks/main.yml
    └── certbot/
        └── tasks/main.yml
```

---

## 📄 `inventory.ini`

```ini
[suitecrm]
your_server_ip_or_domain ansible_user=root
```

---

## 📄 `playbook.yml`

```yaml
- name: Install SuiteCRM with NGINX
  hosts: suitecrm
  become: yes

  vars:
    domain: suitecrm.it.cx.ua
    php_version: "8.1"
    db_name: suitecrm
    db_user: suitecrm_user
    db_pass: StrongDBpass456!
    admin_email: admin@suitecrm.it.cx.ua

  roles:
    - common
    - mariadb
    - nginx
    - suitecrm
    - certbot
```

---

## 📄 `roles/common/tasks/main.yml`

```yaml
- name: Update APT packages
  apt:
    update_cache: yes
    upgrade: dist

- name: Install base packages
  apt:
    name:
      - curl
      - unzip
      - software-properties-common
    state: present
```

---

## 📄 `roles/mariadb/tasks/main.yml`

```yaml
- name: Install MariaDB
  apt:
    name: mariadb-server
    state: present

- name: Start MariaDB
  service:
    name: mariadb
    state: started
    enabled: true

- name: Create database and user
  mysql_db:
    name: "{{ db_name }}"
    state: present

- name: Create database user
  mysql_user:
    name: "{{ db_user }}"
    password: "{{ db_pass }}"
    priv: "{{ db_name }}.*:ALL"
    host: localhost
    state: present
```

---

## 📄 `roles/nginx/tasks/main.yml`

```yaml
- name: Install PHP and NGINX
  apt:
    name:
      - nginx
      - php{{ php_version }}-fpm
      - php{{ php_version }}-cli
      - php{{ php_version }}-common
      - php{{ php_version }}-mysql
      - php{{ php_version }}-xml
      - php{{ php_version }}-zip
      - php{{ php_version }}-curl
      - php{{ php_version }}-mbstring
      - php{{ php_version }}-gd
      - php{{ php_version }}-bcmath
      - php{{ php_version }}-intl
    state: present

- name: Configure NGINX
  template:
    src: suitecrm_nginx.j2
    dest: /etc/nginx/sites-available/{{ domain }}

- name: Enable NGINX config
  file:
    src: /etc/nginx/sites-available/{{ domain }}
    dest: /etc/nginx/sites-enabled/{{ domain }}
    state: link

- name: Remove default NGINX site
  file:
    path: /etc/nginx/sites-enabled/default
    state: absent

- name: Restart NGINX
  service:
    name: nginx
    state: restarted
```

---

## 📄 `roles/nginx/templates/suitecrm_nginx.j2`

```nginx
server {
    listen 80;
    server_name {{ domain }};

    root /var/www/suitecrm/public;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php{{ php_version }}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

---

## 📄 `roles/suitecrm/tasks/main.yml`

```yaml
- name: Download SuiteCRM
  get_url:
    url: https://suitecrm.com/files/162/SuiteCRM-8-2/742/SuiteCRM-8.2.4.zip
    dest: /var/www/suitecrm.zip

- name: Unzip SuiteCRM
  unarchive:
    src: /var/www/suitecrm.zip
    dest: /var/www/
    remote_src: yes

- name: Rename suitecrm folder
  command: mv /var/www/SuiteCRM-* /var/www/suitecrm
  args:
    creates: /var/www/suitecrm

- name: Set permissions
  file:
    path: /var/www/suitecrm
    owner: www-data
    group: www-data
    recurse: yes
```

---

## 📄 `roles/certbot/tasks/main.yml`

```yaml
- name: Install Certbot
  apt:
    name:
      - certbot
      - python3-certbot-nginx
    state: present

- name: Generate SSL certificate
  command: certbot --nginx -d {{ domain }} --non-interactive --agree-tos -m {{ admin_email }}
  args:
    creates: /etc/letsencrypt/live/{{ domain }}/fullchain.pem
```

---

## 🧪 Інструкція запуску

```bash
# 1. Склонуйте:
git clone https://github.com/youruser/suitecrm-ansible.git
cd suitecrm-ansible

# 2. Змініть inventory.ini, додайте ваш сервер

# 3. Запуск плейбуку:
ansible-playbook -i inventory.ini playbook.yml
```

---

### ✅ Результат:

* SuiteCRM буде автоматично встановлено.
* Сертифікат Let's Encrypt + NGINX + PHP.
* Готове до інтеграції в CI/CD, GitHub Actions, Docker.

🔧 Хочеш ZIP або репозиторій GitHub? Я можу згенерувати.
