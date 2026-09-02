# Proxmox Terraform User — Privilege Documentation

## User: `terraform@pve`

**Purpose:** Dedicated Proxmox user for Terraform VM/LXC provisioning.
**Created:** [DATE]
**Created by:** [operator name]

---

## Privileges

The `terraform@pve` user has a **scoped API token** with the minimum
privileges required for Terraform to manage VMs and LXCs.

### Permissions (via Proxmox role assignment)

| Path | Role | Justification |
|------|------|---------------|
| `/vms` | `PVEVMAdmin` | Create, configure, start, stop, delete VMs/LXCs |
| `/storage/local-lvm` | `PVEDatastoreUser` | Allocate disk space for VMs |
| `/pool/jolarca` | `PVEPoolUser` | Assign VMs to the jolarca pool |
| `/sdn` | `NoAccess` | No network configuration (uses pre-configured bridges) |

### What It CAN Do

- Create VMs from cloud-init templates
- Configure CPU, memory, disks, network interfaces
- Start/stop/reboot VMs
- Delete VMs (within the jolarca pool)
- Clone templates
- Read VM status and configuration

### What It CANNOT Do

- Access the Proxmox web UI (no PVEAuditor role on `/`)
- Modify Proxmox host configuration
- Access other tenants' VMs (pool-scoped)
- Modify storage configuration
- Modify network/SDN configuration
- Access the console (no PVEVMConsole)
- Create/modify users or ACLs

---

## API Token

**Token ID:** `terraform@pve!infra`
**Privilege separation:** Disabled (token inherits user permissions)
**Expiry:** No expiry (rotated quarterly per access review)

### How to Create

```bash
# On Proxmox host as joladmin:
pveum user add terraform@pve --comment "Terraform provisioning"
pveum aclmod /vms -user terraform@pve -role PVEVMAdmin
pveum aclmod /storage/local-lvm -user terraform@pve -role PVEDatastoreUser
pveum user token add terraform@pve infra --privsep 0
# Record the token secret — it's shown ONCE
```

### How to Use

```bash
# Export for Terraform session (never write to file)
export TF_VAR_proxmox_api_token="terraform@pve!infra=<TOKEN_SECRET>"

# Run Terraform
cd terraform/environments/staging
terraform init
terraform plan
terraform apply
```

### How to Revoke

```bash
# On Proxmox host:
pveum user token remove terraform@pve infra

# Or disable the user entirely:
pveum user modify terraform@pve --enable 0
```

---

## Security Controls

1. **Token never committed** — exported as env var per session
2. **Least privilege** — scoped to VM management only
3. **Pool-scoped** — can only manage VMs in the `jolarca` pool
4. **Audit logged** — all Proxmox API calls are logged
5. **Quarterly review** — token usage reviewed in access review
6. **No console access** — cannot interact with VM consoles
7. **No host access** — cannot modify Proxmox host configuration

---

## Rotation Procedure

1. Create new token: `pveum user token add terraform@pve infra-new`
2. Update operator environment with new token
3. Verify Terraform works with new token
4. Remove old token: `pveum user token remove terraform@pve infra`
5. Record rotation in access review log

---

## References

- `security/key-custody.md` — token custody procedure
- `security/access-review.md` — quarterly access review
- `terraform/environments/staging/terraform.tfvars.example` — variable placeholders
