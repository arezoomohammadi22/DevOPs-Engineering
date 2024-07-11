```bash
mkdir -p ansible-create-directory/{inventory,playbooks,roles/create_directory/{tasks,vars}} && touch ansible-create-directory/{ansible.cfg,inventory/hosts,playbooks/create_directory.yml,roles/create_directory/tasks/main.yml,roles/create_directory/vars/main.yml}

```
```bash
ansible-playbook playbooks/create_directory.yml
```

```bash
mkdir -p ansible-create-directory/{inventory,playbooks,roles/create_directory/{tasks,vars}} && \
echo "[defaults]
inventory = inventory/hosts
roles_path = roles" > ansible-create-directory/ansible.cfg && \
echo "[webservers]
server1.example.com
server2.example.com" > ansible-create-directory/inventory/hosts && \
echo "---
- name: Create a directory on remote servers
  hosts: webservers
  become: yes
  roles:
    - create_directory" > ansible-create-directory/playbooks/create_directory.yml && \
echo "--- 
- name: Ensure the directory is created
  file:
    path: \"{{ directory_path }}\"
    state: directory
    mode: '0755'" > ansible-create-directory/roles/create_directory/tasks/main.yml && \
echo "--- 
directory_path: /opt/myapp" > ansible-create-directory/roles/create_directory/vars/main.yml
```
```bash
:D
```
