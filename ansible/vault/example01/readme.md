# Ansible Playbook: Secure MySQL Setup with Ansible Vault

This Ansible playbook installs and configures MySQL securely using **Ansible Vault** to store sensitive credentials.

## 📌 Features
- Installs **MariaDB/MySQL**
- Sets **MySQL root password securely**
- Uses **Ansible Vault** for encryption
- Supports **Ubuntu, Debian, CentOS, and RedHat**

## 📂 Project Structure
```
.
├── mysql_setup.yml        # Ansible Playbook
├── inventory.ini          # Inventory file (hosts)
├── secret.yml             # Encrypted Vault file (stores MySQL password)
└── README.md              # Documentation
```

## 🔐 Setting Up Ansible Vault
Before running the playbook, **encrypt sensitive credentials** using Ansible Vault.

1. **Create an encrypted file:**
   ```sh
   ansible-vault create secret.yml
   ```
   Add the following content (replace with your secure values):
   ```yaml
   mysql_root_password: "StrongRootPass123!"
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

## 📜 Playbook (`mysql_setup.yml`)
```yaml
---
- name: Securely Configure MySQL
  hosts: database_servers
  become: yes
  vars_files:
    - secret.yml  # Load encrypted vault file

  tasks:
    - name: Install MySQL
      package:
        name: mariadb-server
        state: present

    - name: Ensure MySQL service is running
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
```

## 📌 Inventory (`inventory.ini`)
Define the target **MySQL server(s)** in your inventory:
```ini
[database_servers]
db1 ansible_host=192.168.1.100 ansible_user=root ansible_python_interpreter=/usr/bin/python3
```

## 🚀 Running the Playbook
Run the playbook with Vault password prompt:
```sh
ansible-playbook mysql_setup.yml --ask-vault-pass
```

Or use a **password file**:
```sh
echo "mysecretpassword" > vault_pass.txt
ansible-playbook mysql_setup.yml --vault-password-file vault_pass.txt
```

## 🔄 Updating the Vault Password
To change the encryption password:
```sh
ansible-vault rekey secret.yml
```

## 🛠 Troubleshooting
- **Permission denied?** Ensure `become: yes` is set.
- **Playbook failing?** Use `-vvv` for detailed logs:
  ```sh
  ansible-playbook mysql_setup.yml --ask-vault-pass -vvv
  ```
- **MySQL login error?** Run:
  ```sh
  sudo mysql_secure_installation
  ```

## 📖 Learn More
- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)

---

🛡 **Now you can securely configure MySQL with Ansible Vault!** 🚀
