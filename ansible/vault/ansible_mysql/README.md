# MySQL in Docker via Ansible + Vault (FA)
این پروژه یک کانتینر MySQL را با استفاده از Ansible راه‌اندازی می‌کند و رمزها را با Vault محافظت می‌کند.

## پیش‌نیازها
- روی کنترل‌نود: نصب Ansible و کالکشن community.docker
  ```bash
  ansible-galaxy collection install community.docker
  ```
- روی تارگت (سرور): Ubuntu/Debian. اگر Docker نصب نیست، متغیر `install_docker: true` باقی بماند تا نصب شود.

## گام‌ها
1. فایل اسرار را رمزنگاری کن:
   ```bash
   cd ansible_mysql
   ansible-vault encrypt group_vars/mysql/vault.yml
   ```

2. اجرای پلی‌بوک:
   ```bash
   ansible-playbook -i inventories/prod/hosts site.yml --ask-vault-pass
   ```

3. تست:
   ```bash
   # روی سرور مقصد
   docker ps
   docker logs mysql --tail 50
   ```

## متغیرها
- `mysql_bind_port`: پورت MySQL روی هاست (پیش‌فرض 3306)
- `mysql_db`: نام دیتابیس اولیه
- Vault:
  - `mysql_root_password`, `mysql_user`, `mysql_password`
