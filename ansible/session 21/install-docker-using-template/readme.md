```bash
mkdir -p ansible-docker-playbook/{inventory,playbooks,roles/install_docker/{tasks,files,templates,handlers,vars}} && \
echo "[defaults]
inventory = inventory/hosts
roles_path = roles" > ansible-docker-playbook/ansible.cfg && \
echo "[appserver]
server1.example.com
server2.example.com" > ansible-docker-playbook/inventory/hosts && \
echo "---
- name: Install Docker on Ubuntu
  hosts: appserver
  become: yes

  roles:
    - install_docker" > ansible-docker-playbook/playbooks/install_docker.yml && \
echo "---
- name: Update apt package cache and install dependencies
  apt:
    name: \"{{ item }}\"
    state: present
  loop:
    - apt-transport-https
    - ca-certificates
    - curl
    - gnupg-agent
    - software-properties-common

- name: Add Docker GPG key
  apt_key:
    url: https://download.docker.com/linux/ubuntu/gpg
    state: present

- name: Add Docker repository
  apt_repository:
    repo: \"deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable\"
    state: present

- name: Update apt package cache (again) with Docker repository
  apt:
    update_cache: yes

- name: Install Docker
  apt:
    name: docker
    state: present

- name: Ensure Docker service is started and enabled
  service:
    name: docker
    state: started
    enabled: yes" > ansible-docker-playbook/roles/install_docker/tasks/main.yml

```

```bash
ansible-docker-playbook/
├── ansible.cfg
├── inventory
│   └── hosts
├── playbooks
│   └── install_docker.yml
└── roles
    └── install_docker
        ├── tasks
        │   └── main.yml
        ├── files
        ├── templates
        ├── handlers
        └── vars


```
```bash
ansible-playbook playbooks/install_docker.yml
```
