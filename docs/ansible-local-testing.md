# Ansible Local Testing Guide

This document explains how to run Molecule tests locally for all Ansible
roles before pushing to CI.

## Prerequisites

```bash
# Install Docker (required for Molecule Docker driver)
sudo apt-get install -y docker.io
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect

# Install Python tooling
pip install --user \
  "ansible>=9,<11" \
  "ansible-lint>=24.9" \
  "molecule[docker]>=24.9"
```

## Directory Structure

```text
ansible/
├── ansible.cfg              # Vault integration, SSH pipelining
├── requirements.yml         # Pinned collections
├── inventories/
│   ├── staging/hosts.yml    # Fill-in-the-blanks for Proxmox
│   └── production/          # Production (separate vault)
├── playbooks/               # 00-hardening through 60-backup
├── roles/                   # One role per concern
│   ├── hardening/
│   ├── wireguard/
│   ├── postgresql/
│   ├── vault/
│   ├── minio/
│   ├── nginx/
│   └── backup/
├── group_vars/all/          # Global variables
└── vault/{staging,prod}/    # ansible-vault encrypted secrets
```

## Running Tests

### Test a single role

```bash
cd ansible

# Test the hardening role
cd roles/hardening
molecule test

# Test with verbose output
molecule test -v
```

### Test all roles

```bash
cd ansible

# Iterate over all roles
for role in roles/*/; do
  echo "Testing $(basename $role)..."
  (cd "$role" && molecule test)
done
```

### Molecule lifecycle stages

```bash
# Create test containers
molecule create

# Run the playbook (converge)
molecule converge

# Run verification tests
molecule verify

# Destroy test containers
molecule destroy

# Full lifecycle (create → converge → idempotency → verify → destroy)
molecule test
```

### Idempotency check

Molecule's `test` command includes an idempotency check by default.
Run the playbook twice; the second run should report zero changes:

```bash
cd roles/hardening
molecule converge   # First run — applies changes
molecule converge   # Second run — should show 0 changed
molecule verify     # Run verification tests
molecule destroy    # Clean up
```

## Linting

```bash
cd ansible

# Lint all playbooks and roles
ansible-lint

# Lint a specific playbook
ansible-lint playbooks/00-hardening.yml

# Check YAML syntax
yamllint -c .yamllint roles/*/tasks/*.yml
```

## Syntax Check

```bash
cd ansible

# Check syntax of all playbooks against staging inventory
for p in playbooks/*.yml; do
  ansible-playbook --syntax-check -i inventories/staging/hosts.yml "$p"
done
```

## Troubleshooting

### Docker permission denied

```bash
sudo usermod -aG docker $USER
# Log out and back in
```

### Molecule can't pull Docker image

```bash
# Pull the image manually first
docker pull geerlingguy/docker-ubuntu2204-ansible:latest
```

### Ansible collections not found

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

### Systemd in Docker containers

Some roles require systemd. The Molecule configuration uses
`privileged: true` and `cgroupns_mode: host` to enable systemd in
Docker containers. If you see systemd errors, ensure Docker is
running in rootful mode (not rootless).

## CI Integration

The CI workflow (`.github/workflows/ansible.yml`) runs:

1. **ansible-lint** — static analysis on all playbooks and roles
2. **Syntax check** — validates playbook syntax against staging inventory
3. **Molecule test** — runs each role's Molecule suite in Docker

All three must pass before a PR can merge.
