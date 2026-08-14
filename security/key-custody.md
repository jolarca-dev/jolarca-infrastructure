# Key custody — who holds what

Every credential in this infrastructure has named custodians, a rotation
cadence, and a loss/recovery path. An unnamed secret is an unmanaged risk
(SOC 2 CC6.1, ISO 27001 A.5.17).

**Rule of dual control:** any credential marked *(dual)* requires two named
custodians; no single person may hold, use, or rotate it alone.

## Register

| Credential                     | Custody                 | Storage        | Rotation            | Loss path                          |
|--------------------------------|-------------------------|----------------|---------------------|------------------------------------|
| GitHub PAT — TF read-only      | CI secret, 1 operator   | org secret     | 90d (runbook)       | `../docs/runbooks/github-token-rotation.md` |
| GitHub PAT — TF write          | CI env secret, 1 operator| env secret    | 90d (runbook)       | same runbook; applies require re-review |
| ansible-vault password — staging | 1 operator            | Vaultwarden    | on personnel change | re-encrypt vault files             |
| ansible-vault password — production *(dual)* | 2 operators | Vaultwarden (split entries) | on personnel change + annually | dual-control rekey (`../scripts/rotate-vault-password.sh`) |
| GCS state CMEK — staging       | 1 operator + CI SA      | Cloud KMS      | annually + on incident | key version rotation, no downtime |
| GCS state CMEK — production *(dual)* | 2 custodians      | Cloud KMS      | annually + on incident | key version rotation; revocation = state-compromise runbook |
| WireGuard private keys         | per-host only           | host filesystem| on personnel/device change | `../docs/runbooks/wireguard-key-rotation.md` |
| HashiCorp Vault unseal keys    | 3-of-5 key holders      | sealed, offline| annually            | `../docs/runbooks/vault-sealed.md` |
| Break-glass GCP SA key         | 2 custodians *(dual)*   | Vaultwarden    | after EVERY use     | `../terraform/README.md` break-glass |

## Invariants

1. Custodians are named people, not teams. Leaving the org = rotation event.
2. Rotation is always logged in CHANGELOG.md + compliance evidence repo.
3. No credential lives in git, state, tfvars, container images, or CI logs —
   enforced by gitleaks + `../scripts/audit-no-secrets.sh`.
4. Quarterly: this register is reconciled against reality in
   `access-review.md`. Mismatches are findings.
