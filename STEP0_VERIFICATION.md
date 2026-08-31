# STEP 0 — Remote State Backend: Operator Verification Suite (ADR-0003)

Operator-facing checklist for the local → GCS state migration. Every
apply is HUMAN-GATED: nothing below marked ⛔ runs without your explicit
confirmation in the change record. Evidence copies go to `jolarca-compliance`
(SOC 2 CC8.1).

Frozen identifiers:

| Env        | Bucket                           | Prefix                 |
|------------|----------------------------------|------------------------|
| staging    | `jolm-tfstate-staging-3c4a45`    | `terraform/staging`    |
| production | `jolm-tfstate-production-857941` | `terraform/production` |

---

## V0 — Pre-flight (already verified 2026-08-15; re-run in the window)

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 0.1 | State files gitignored | `grep -n 'tfstate' .gitignore` | `*.tfstate` and `*.tfstate.*` present |
| 0.2 | No secrets in repo/history | `gitleaks detect --source . --no-banner --redact` | `no leaks found` |
| 0.3 | No credentials in local state | pattern scan for PAT/PEM/JWT fields in `terraform.tfstate` | 0 hits (provider schema hashes only) |
| 0.4 | Static gates | `make check` | exit 0 |

## Apply ledger (fill in during the change window)

| Gate | Command | Operator confirmed | Outcome |
|------|---------|--------------------|---------|
| ⛔ A1 | `terraform apply` (bootstrap, workspace `staging`) | ☐ timestamp/name | ☐ |
| ⛔ A2 | overlay `zz-remote-backend.tmp.tf` + `terraform init -migrate-state -backend-config=bucket=… -backend-config=prefix=…` (staging) | ☐ | ☐ |
| ⛔ A3 | `terraform apply` (bootstrap, workspace `production`) — IRREVERSIBLE retention lock | ☐ | ☐ |
| ⛔ A4 | overlay `zz-remote-backend.tmp.tf` + `terraform init -migrate-state -backend-config=bucket=… -backend-config=prefix=…` (production) | ☐ | ☐ |

## V1 — Staging custody stack (after A1)

```bash
B=jolm-tfstate-staging-3c4a45
gcloud storage buckets describe gs://$B \
  --format='value(default_kms_key_name,versioning.enabled,uniform_bucket_level_access.enabled,public_access_prevention)'
```
Expected: `projects/<P>/locations/europe-west1/keyRings/tfstate-staging/cryptoKeys/tfstate-staging  True  True  enforced`

```bash
gcloud storage buckets get-iam-policy gs://$B --format='value(bindings.role,bindings.members)'
```
Expected: ONLY `roles/storage.objectAdmin → tfstate-staging@<P>.iam.gserviceaccount.com`
(redacted exception list is empty; NO allUsers / allAuthenticatedUsers).

## V2 — Staging migration (after A2)

```bash
cd terraform/environments/staging
terraform plan -lock=false
```
Expected: `No changes. Your infrastructure matches the configuration.`

## V3 — Production custody stack (after A3)

Same commands as V1 with `B=jolm-tfstate-production-857941`; additionally:

```bash
gcloud storage buckets describe gs://$B --format='value(retention_policy)'
```
Expected: retention period 90d and `is_locked: True` (irreversible by design).

## V4 — Production migration is diff-PRESERVING (after A4)

Fleet import is a later workstream; production currently plans changes by
design. The migration must not change the diff AT ALL:

```bash
diff <(grep -E 'will be|must be|Plan:' /tmp/pre-migration.txt) \
     <(grep -E 'will be|must be|Plan:' /tmp/post-migration.txt)
```
Expected: empty output (identical actions/counts before vs after).

## V5 — Remote state object verified

```bash
gcloud storage objects list gs://jolm-tfstate-production-857941/terraform/production/ --all-versions
```
Expected: `default.tfstate` present, ≥1 version, KMS-encrypted.

## V6 — Local state eradicated (ONLY after V1–V5 all pass)

```bash
ls terraform/environments/production/terraform.tfstate* 2>/dev/null   # expected: no output
ls terraform/bootstrap/terraform.tfstate.d/ 2>/dev/null               # shredded after window
```
Then remove the LOCAL BACKEND EXCEPTION block in
`scripts/audit-no-secrets.sh` and confirm:

```bash
bash scripts/audit-no-secrets.sh    # expected: exit 0, no FORBIDDEN lines
```

## V7 — Repo + CI clean

```bash
gitleaks detect --source . --no-banner --redact   # no leaks
make check                                        # exit 0
```
CI: branch protection checks `ci` + `security` green on the PR.

## V8 — Follow-ups (file as issues; do not silently drop)

- [ ] WIF pool/provider + `ci_principal` binding (`docs/workload-identity-federation.md`).
- [ ] **Phase B PR**: permanent `backend "gcs" {}` blocks + repo var `TF_REMOTE_STATE=true`; overlays deleted; CI green remote-native.
- [ ] Fleet import (jolarca-compliance/legal/data/marketplace) into production state — the STEP after STEP 0.
- [ ] Key custodians recorded in `security/key-custody.md` (both KMS keys).
- [ ] Backup layer (`backup/terraform-state/`) registered against the new buckets.
- [ ] Solo-era two-person sign-off evidence when operator #2 onboards.
