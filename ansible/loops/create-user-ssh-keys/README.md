# Ansible Loops Demo (single playbook: project.yaml)

## Structure
```
ansible-loops-project/
├── project.yaml
├── inventories/
│   └── dev/hosts.ini
└── roles/
    └── common/
        ├── tasks/main.yml
        ├── vars/main.yml
        └── templates/motd.j2
```

## Quick start
1) Edit `inventories/dev/hosts.ini` and set your real hosts or keep localhost.
2) Run:
   ```bash
   ansible-playbook -i inventories/dev/hosts.ini project.yaml
   ```

## What it demonstrates
- Loop over a list (packages) with `loop_var` and `label`.
- Loop over a list of dicts (users).
- Template rendering with readable loop output (`loop_control.label`).
- Modern `subelements` pattern via `query('subelements', ...)` for users' SSH keys.
