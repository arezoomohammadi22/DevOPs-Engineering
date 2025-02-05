# Ansible Playbook: Full LAMP Stack Deployment with Ansible Vault

This Ansible playbook sets up a **LAMP (Linux, Apache, MySQL, PHP) stack** securely using **Ansible Vault** to store MySQL credentials. It automates:
- Installing **Apache**, **MySQL**, and **PHP**
- Configuring **Virtual Hosts** for multiple domains
- Deploying a **sample PHP application**
- Setting up a **secure MySQL database**
- Using **Ansible Vault** to store passwords securely

---

## 📂 Project Structure
```
.
├── lamp_setup.yml        # Main Ansible Playbook
├── inventory.ini         # Inventory file (hosts)
├── secret.yml            # Encrypted Vault file (MySQL credentials)
├── templates/
│   ├── php_app/index.php # Sample PHP application
│   ├── vhost.conf.j2     # Virtual Host Template
└── README.md             # Documentation
```

---

## 🔐 Setting Up Ansible Vault
Before running the playbook, **encrypt sensitive credentials** using Ansible Vault.

1. **Create an encrypted file:**
   ```sh
   ansible-vault create secret.yml
   ```
   Add the following content:
   ```yaml
   mysql_root_password: "StrongPass123!"
   mysql_user: "web_admin"
   mysql_user_password: "SecurePass456!"
   ```

2. **Encrypt an existing file** (optional):
   ```sh
   ansible-vault encrypt secret.yml
   ```

3. **View or edit encrypted file:**
   ```sh
   ansible-vault view secret.yml
   ansible-vault edit secret.yml
   ```

---

## 📜 Playbook (`lamp_setup.yml`)
```yaml
---
- name: Deploy a Secure LAMP Stack
  hosts: web_servers
  become: yes
  vars_files:
    - secret.yml  # Load encrypted vault file

  tasks:
    - name: Install LAMP Packages
      package:
        name:
          - apache2
          - php
          - php-mysql
          - mariadb-server
        state: present
      notify: Restart Apache

    - name: Ensure Apache Service is Running
      service:
        name: apache2
        state: started
        enabled: yes

    - name: Ensure MySQL Service is Running
      service:
        name: mariadb
        state: started
        enabled: yes

    - name: Set MySQL Root Password
      mysql_user:
        name: root
        password: "{{ mysql_root_password }}"
        host_all: true
        login_unix_socket: true

    - name: Create MySQL Database
      mysql_db:
        name: my_database
        state: present
        login_user: root
        login_password: "{{ mysql_root_password }}"

    - name: Create MySQL User with Permissions
      mysql_user:
        name: "{{ mysql_user }}"
        password: "{{ mysql_user_password }}"
        priv: "my_database.*:ALL"
        host: "%"
        state: present
        login_user: root
        login_password: "{{ mysql_root_password }}"

    - name: Deploy Virtual Host Configuration
      template:
        src: templates/vhost.conf.j2
        dest: "/etc/apache2/sites-available/mysite.conf"
      notify: Restart Apache

    - name: Enable Virtual Host
      command: a2ensite mysite.conf
      notify: Restart Apache

    - name: Deploy PHP Application
      copy:
        src: templates/php_app/index.php
        dest: /var/www/html/index.php
        mode: '0644'

  handlers:
    - name: Restart Apache
      service:
        name: apache2
        state: restarted
```

---

## 📌 Inventory (`inventory.ini`)
Define your web servers in the **inventory** file:
```ini
[web_servers]
web1 ansible_host=192.168.1.50 ansible_user=root ansible_python_interpreter=/usr/bin/python3
web2 ansible_host=192.168.1.51 ansible_user=root ansible_python_interpreter=/usr/bin/python3
```

---

## 🚀 Running the Playbook
### **Run with Vault password prompt**
```sh
ansible-playbook lamp_setup.yml --ask-vault-pass
```

### **Run using a password file**
```sh
echo "mysecretpassword" > vault_pass.txt
ansible-playbook lamp_setup.yml --vault-password-file vault_pass.txt
```

---

## 🛠 Troubleshooting
- **Permission issues?** Ensure you have `become: yes` set.
- **Playbook failing?** Use:
  ```sh
  ansible-playbook lamp_setup.yml --ask-vault-pass -vvv
  ```
- **MySQL errors?** Try:
  ```sh
  sudo mysql_secure_installation
  ```

---

## 📖 Learn More
- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [LAMP Stack Guide](https://www.digitalocean.com/community/tutorials/how-to-install-linux-apache-mysql-php-lamp-stack-ubuntu-22-04)

---

🛡 **Now you have a fully automated, secure LAMP stack deployment using Ansible!** 🚀
