# MySQL in Docker via Ansible + Vault

This project launches a **MySQL 8** container with **Ansible**, while keeping database secrets (root password, application user/password) **encrypted with Ansible Vault**.

It’s designed for teaching/demo scenarios and can be adapted to production. Secrets live only in vaulted files and are injected into the container via environment variables.

---

## What this does

- (Optionally) installs Docker on Ubuntu/Debian targets.
- Pulls the `mysql:8.0` image.
- Creates a persistent Docker **volume** (`mysql_data`) for database files.
- Starts a container named `mysql` with:
  - Published port (default **3306** on the host).
  - Environment variables for root/user passwords and an initial database.
- Hides secrets from logs with `no_log: true`.
- Waits until MySQL is reachable before finishing.

---

## Repository layout (subset)

```
ansible_mysql/
├─ inventories/prod/hosts              # target hosts
├─ group_vars/mysql/
│  ├─ app.yml                          # non-sensitive vars: port, DB name, install flag
│  └─ vault.yml                        # 🔐 secrets: root/user passwords (encrypt this)
├─ roles/mysql_docker/tasks/main.yml   # tasks to install Docker, pull image, run container
└─ site.yml                            # main playbook
```

---

## Requirements

**Control node (where you run Ansible):**
- Ansible 2.14+ (tested with 2.17), Python 3.8+

**Managed host(s):**
- Linux (the included Docker installation tasks target **Ubuntu/Debian**)
- SSH access from control node (`ansible_user` with sudo privileges)

### Required Ansible collection
Only this Docker example needs a collection:
```bash
ansible-galaxy collection install community.docker
```

> The role also installs the Python Docker SDK on the target (via `pip`) so Ansible’s Docker modules can talk to the Docker Engine.

---

## Inventory example

`inventories/prod/hosts`:
```ini
[mysql]
mysql-01 ansible_host=203.0.113.30 ansible_user=ubuntu
```

> If the remote Python path isn’t standard, add: `ansible_python_interpreter=/usr/bin/python3`

---

## Variables

`group_vars/mysql/app.yml` (non-sensitive):
```yaml
install_docker: true            # set to false if Docker is already installed
mysql_container_name: mysql
mysql_image: mysql:8.0
mysql_bind_port: 3306           # host port -> container 3306
mysql_db: demo                  # initial database to create
```

`group_vars/mysql/vault.yml` (sensitive – **encrypt this**):
```yaml
mysql_root_password: "StrongRootPass123!"
mysql_user: "demo_user"
mysql_password: "StrongUserPass456!"
```

---

## Encrypt secrets with Vault

From the project root:
```bash
cd ansible_mysql
ansible-vault encrypt group_vars/mysql/vault.yml
```

To edit later:
```bash
ansible-vault edit group_vars/mysql/vault.yml
```

---

## Run the playbook

```bash
ansible-playbook -i inventories/prod/hosts site.yml --ask-vault-pass
```
or (CI-friendly):
```bash
echo "MyVaultPassword123" > ~/.vault_pass.txt && chmod 600 ~/.vault_pass.txt
ansible-playbook -i inventories/prod/hosts site.yml --vault-password-file ~/.vault_pass.txt
```

---

## Validate

On the target host:
```bash
docker ps
docker logs mysql --tail 50
```

Connect to MySQL (replace IP/host as needed):
```bash
mysql -h <host-ip> -P 3306 -u demo_user -p
# enter the password from group_vars/mysql/vault.yml
```

Or via Docker:
```bash
docker exec -it mysql mysql -uroot -p
```

---

## Security best practices

- Keep **only secrets** in `vault.yml` and commit it encrypted.
- Use `no_log: true` on tasks that handle passwords.
- Restrict who can read your Ansible repo and vault password file.
- Add your vault password file (if used) to `.gitignore`.

---

## Troubleshooting

- **`ERROR! could not find collection community.docker`**  
  Install it: `ansible-galaxy collection install community.docker`

- **Permission denied to Docker**  
  Ensure Ansible runs tasks with `become: yes` (already set). If you run docker manually, you may need `sudo`.

- **Port already in use (bind error)**  
  Change `mysql_bind_port` in `group_vars/mysql/app.yml`.

- **MySQL not reachable / wait_for timeout**  
  Check firewall rules, confirm the container is healthy: `docker logs mysql`.

- **Wrong MySQL credentials**  
  Verify `vault.yml` values and re-run. You can `docker rm -f mysql && docker volume rm mysql_data` to reset (see Cleanup).

---

## Cleanup / Reset

On the target host:
```bash
# stop & remove container
docker rm -f mysql

# remove the persistent volume (data loss!)
docker volume rm mysql_data
```

---

## Customization ideas

- Switch image version: `mysql:8.4`, `mysql:5.7` (mind compatibility).
- Change container name/port/volume name in `app.yml`.
- Bind-mount a custom `my.cnf` for server tuning.
- Add more users/databases by extending the role.
- Adapt Docker install tasks for RHEL/CentOS or set `install_docker: false` and preinstall Docker yourself.

---

## Files of interest

- `roles/mysql_docker/tasks/main.yml` – main logic (install Docker, pull image, create volume, run container, wait_for).  
- `group_vars/mysql/vault.yml` – **vaulted secrets** for MySQL root/user.  
- `site.yml` – playbook entry-point.  
- `inventories/prod/hosts` – where your MySQL target(s) are defined.

---

Happy automating! If you need a multi-environment layout (dev/stage/prod) with separate vaults for each, this project can be extended easily.
