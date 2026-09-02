# Day 1 Premise Check — HALT ON FAILURE

**Execute BEFORE any Day 2 work.** Every check must pass. If any check
fails: STOP, remediate Day 1, re-verify.

**Operator:** [name]
**Date:** [YYYY-MM-DD]
**Proxmox host:** [hostname/IP]

---

## 1. Day 1 Artifacts Committed

```bash
# Verify Day 1 commits exist
git log --oneline -10

# Verify audit/day1/ contains hardening evidence
ls audit/day1/
```

**Expected:** At least one Day 1 commit; audit/day1/ contains
hardening verification output.

**Result:** [ ] PASS / [ ] FAIL
**Evidence:** [paste output]

---

## 2. SSH as Non-Root Admin

```bash
ssh joladmin@<proxmox-ip> 'whoami && sudo -n true && echo SUDO_OK'
```

**Expected:** Output: `joladmin` + `SUDO_OK`

**Result:** [ ] PASS / [ ] FAIL
**Evidence:** [paste output]

---

## 3. Break-Glass Account

```bash
ssh joladmin@<proxmox-ip> 'sudo passwd -S breakglass'
```

**Expected:** Status shows `L` (locked). Credentials sealed offline
in envelope per `security/key-custody.md`.

**Result:** [ ] PASS / [ ] FAIL
**Evidence:** [paste output — DO NOT paste credentials]

---

## 4. Host Firewall

```bash
ssh joladmin@<proxmox-ip> 'sudo pve-firewall status'
ssh joladmin@<proxmox-ip> 'sudo ss -tlnp'
```

**Expected:** Firewall shows `enabled`. Only expected ports listen
(8006/tcp for Proxmox UI, 22/tcp for SSH, possibly 51820/udp for
WireGuard if pre-configured).

**Result:** [ ] PASS / [ ] FAIL
**Evidence:** [paste output]

---

## 5. Storage Layout

```bash
ssh joladmin@<proxmox-ip> 'sudo pvesm status'
ssh joladmin@<proxmox-ip> 'sudo zfs list' 2>/dev/null || \
ssh joladmin@<proxmox-ip> 'sudo lvs'
```

**Expected:** Storage matches Day 1 design — segmented datasets
for VMs, backups, and ISO templates.

**Result:** [ ] PASS / [ ] FAIL
**Evidence:** [paste output]

---

## 6. P1–P7 Code Present

```bash
# Terraform modules
ls terraform/modules/

# Ansible playbooks
ls ansible/playbooks/

# Ansible roles
ls ansible/roles/

# Monitoring configs
ls monitoring/
```

**Expected:** All modules (proxmox-vm, proxmox-lxc, networking, gke),
all playbooks (00 through 95), all roles (9), monitoring configs.

**Result:** [ ] PASS / [ ] FAIL
**Evidence:** [paste output]

---

## Summary

| Check | Result |
|-------|--------|
| Day 1 artifacts committed | [ ] |
| SSH as non-root admin | [ ] |
| Break-glass account locked | [ ] |
| Host firewall enabled | [ ] |
| Storage layout matches | [ ] |
| P1–P7 code present | [ ] |

**Overall:** [ ] ALL PASS — proceed to Day 2 / [ ] FAILED — STOP

**Operator signature:** _______________________________
**Date:** _______________
