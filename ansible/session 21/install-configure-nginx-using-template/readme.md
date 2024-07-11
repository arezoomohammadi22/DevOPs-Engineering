```bash
mkdir -p ansible-nginx-playbook/{inventory,playbooks,roles/nginx/{tasks,templates,handlers,vars,files},group_vars} && touch ansible-nginx-playbook/{ansible.cfg,inventory/hosts,playbooks/nginx.yml,roles/nginx/tasks/main.yml,roles/nginx/templates/server_block.j2,roles/nginx/handlers/main.yml,roles/nginx/vars/main.yml,roles/nginx/files/index.html,group_vars/all.yml}
```

```bash
ansible-nginx-playbook/
├── ansible.cfg
├── inventory/
│   └── hosts
├── playbooks/
│   └── nginx.yml
├── roles/
│   └── nginx/
│       ├── tasks/
│       │   └── main.yml
│       ├── templates/
│       │   └── server_block.j2
│       ├── handlers/
│       │   └── main.yml
│       ├── vars/
│       │   └── main.yml
│       └── files/
│           └── index.html
└── group_vars/
    └── all.yml
```
