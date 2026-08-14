# Key custody — who holds what

Every credential in this infrastructure has named custodians, a rotation
cadence, and a loss/recovery path. An unnamed secret is an unmanaged risk
(SOC 2 CC6.1, ISO 27001 A.5.17).

**Rule of dual control:** any credential marked *(dual)* requires two named
custodians; no single person may hold, use, or rotate it alone.

## Register

| Credential                     | Custody                 | Storage        | Rotation            | Loss path                          |
|--------------------------------|-------------------------|----------------|---------------------|------------------------------------|
| GitHub PAT — TF read-only      | CI secret, 1 operator   | repo secret `TF_GITHUB_TOKEN_READONLY` | 90d (runbook) | `../docs/runbooks/github-token-rotation.md` |
| GitHub PAT — TF write          | CI env secret, 1 operator| env secret `TF_GITHUB_TOKEN_WRITE` (production env) | 90d (runbook) | same runbook; applies require re-review |
| ansible-vault password — staging | 1 operator            | Vaultwarden    | on personnel change | re-encrypt vault files             |
| ansible-vault password — production *(dual)* | 2 operators | Vaultwarden (split entries) | on personnel change + annually | dual-control rekey (`../scripts/rotate-vault-password.sh`) |
| GCS state CMEK — staging       | 1 operator + CI SA      | Cloud KMS      | annually + on incident | key version rotation, no downtime |
| GCS state CMEK — production *(dual)* | 2 custodians      | Cloud KMS      | annually + on incident | key version rotation; revocation = state-compromise runbook |
| WireGuard private keys         | per-host only           | host filesystem| on personnel/device change | `../docs/runbooks/wireguard-key-rotation.md` |
| HashiCorp Vault unseal keys    | 3-of-5 key holders      | sealed, offline| annually            | `../docs/runbooks/vault-sealed.md` |
| Break-glass GCP SA key         | 2 custodians *(dual)*   | Vaultwarden    | after EVERY use     | `../terraform/README.md` break-glass |

## Known interim deviations (tracked)

1. **Shared interim PAT**: both TF tokens currently hold the SAME classic
   PAT (the active operator token) instead of separate fine-grained
   read/write PATs. Rotation to the doctrinal pair is a tracked issue —
   the first rotation must split them.
2. **No environment approval gate**: required reviewers on private org
   repos need GitHub Team+; the current plan cannot enforce the manual
   approval step on `production` applies. Compensating controls: write
   token isolated in the environment secret, dispatch limited to repo
   collaborators, all applies visible via drift detection. Plan upgrade
   intentionally deferred — with a single operator it would add no control
   value (see deviation 3).
3. **Solo-era operation**: exactly one operator exists today; a second
   person (programmer, designated future second custodian) is not yet
   engaged. All human review gates (branch-protection review counts,
   CODEOWNERS reviews, dual control) are deferred and enforcement rides on
   automated gates (required status checks, policy scans, drift
   detection). Activation checklist lives in CONTRIBUTING.md
   ("Onboarding trigger"). Until then: sole operator is custodian of every
   credential above marked single-holder; every *(dual)* item is held in
   escrow-as-design only, with the sole operator as interim holder —
   logged in the access review each quarter.

## Invariants

1. Custodians are named people, not teams. Leaving the org = rotation event.
2. Rotation is always logged in CHANGELOG.md + compliance evidence repo.
3. No credential lives in git, state, tfvars, container images, or CI logs —
   enforced by gitleaks + `../scripts/audit-no-secrets.sh`.
4. Quarterly: this register is reconciled against reality in
   `access-review.md`. Mismatches are findings.
