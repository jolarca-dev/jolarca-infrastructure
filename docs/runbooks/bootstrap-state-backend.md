# Runbook: State backend bootstrap (ADR-0003)

> **Class:** Crit — approved change window + two-person rule
> (solo era: the deviation is recorded in `security/key-custody.md`;
> every apply below still requires an explicit human confirmation).
>
> **What this creates:** per environment — GCS state bucket (CMEK,
> versioned, locked down), KMS keyring/key, dedicated state SA.
> **What this must never do:** share anything between staging and
> production, commit credentials, delete local state before remote
> verification.

Frozen identifiers (already committed — do NOT change one side without
the other):

| Env        | Bucket                          | KMS key            | State SA           |
|------------|---------------------------------|--------------------|--------------------|
| staging    | `jolm-tfstate-staging-3c4a45`   | `tfstate-staging`  | `tfstate-staging`  |
| production | `jolm-tfstate-production-857941`| `tfstate-production`| `tfstate-production`|

## 0. Prerequisites (verify, don't assume)

```bash
# Operator identity only — never an SA JSON key.
gcloud auth login --update-adc
gcloud config set project <PROJECT_ID>          # operator-supplied
gcloud services enable storage.googleapis.com cloudkms.googleapis.com

# Repo hygiene gates (must pass before ANY apply):
git -C <repo> status --porcelain                # expected: clean tree
grep -n 'tfstate' .gitignore                    # *.tfstate, *.tfstate.*
gitleaks detect --source . --no-banner --redact # expected: no findings
```

Record: change-request ID, start timestamp, both operator names (solo
era: single operator + deviation note) in the `jolarca-compliance` change
log. **GATE 0 — operator confirms to proceed.**

## 1. Bootstrap the STAGING custody stack

```bash
cd terraform/bootstrap
terraform init                                  # local backend, by design
terraform workspace new staging                 # or: workspace select staging

# Operator-supplied; never committed:
export TF_VAR_project_id=<STAGING_PROJECT_ID>

terraform plan                                  # READ freely; inspect
# Expected: KMS keyring+key, bucket, SA, 3 IAM bindings, audit config.
# Verify the bucket name in the plan == jolm-tfstate-staging-3c4a45.
```

**GATE 1 — human-gated apply.** Only after the operator reviews the plan:

```bash
terraform apply
# Record outputs (bucket_name, kms_key_id, *_email) in
# security/key-custody.md and the change record.
```

## 2. Verify the staging bucket (independent of Terraform)

```bash
B=jolm-tfstate-staging-3c4a45
gcloud storage buckets describe gs://$B \
  --format='value(default_kms_key_name,versioning.enabled,\
uniform_bucket_level_access.enabled)'
# Expected: projects/.../tfstate-staging...  True  True
gcloud storage buckets get-iam-policy gs://$B
# Expected: ONLY tfstate-staging@... objectAdmin; no allUsers/allAuthenticatedUsers
```

## 3. Migrate STAGING state (staging has no resources yet — trivial)

```bash
cd ../environments/staging

# Backend blocks are NOT committed pre-migration (they break CI dry
# plans). Use the gitignored overlay for the migration window:
cat > zz-remote-backend.tmp.tf <<'EOF'
terraform {
  backend "gcs" {}
}
EOF

# HUMAN-GATED: migrates (empty) local state to GCS. key=value pairs from
# backends/staging.backend.hcl:
terraform init -migrate-state \
  -backend-config=bucket=jolm-tfstate-staging-3c4a45 \
  -backend-config=prefix=terraform/staging
terraform plan -lock=false
# Expected: "No changes" (staging manages nothing yet).
# The overlay stays on disk until step 9 lands the permanent block.
```

Soak: leave staging on the remote backend until the production window.

## 4. Bootstrap the PRODUCTION custody stack

Same shape as step 1, isolated workspace and project:

```bash
cd ../../bootstrap
terraform workspace new production
export TF_VAR_project_id=<PRODUCTION_PROJECT_ID>   # SEPARATE project per
                                                   # ADR-0002 if split; else
                                                   # same project, separate
                                                   # bucket+key+SA by design
terraform plan
```

**GATE 2 — human-gated apply.** NOTE: production applies with
`retention_days=90, lock_retention=true` — the retention lock is
IRREVERSIBLE by design; that is the point.

```bash
terraform apply
```

## 5. Capture the production plan baseline BEFORE migration

Production state currently drifts from config (fleet import is the NEXT
workstream — the migration must be diff-preserving, not diff-freeing):

```bash
cd ../environments/production
terraform plan -lock=false -out=/tmp/pre-migration.plan   # local state
terraform show -no-color /tmp/pre-migration.plan > /tmp/pre-migration.txt
```

## 6. Migrate PRODUCTION state

```bash
# Same gitignored overlay as step 3:
cat > zz-remote-backend.tmp.tf <<'EOF'
terraform {
  backend "gcs" {}
}
EOF

# HUMAN-GATED: copies terraform.tfstate into
# gs://jolm-tfstate-production-857941/terraform/production/default.tfstate
terraform init -migrate-state \
  -backend-config=bucket=jolm-tfstate-production-857941 \
  -backend-config=prefix=terraform/production
# Answer 'yes' to the migration prompt ONLY after GATE 3 confirmation.
```

**GATE 3** happens in chat before this command runs.

## 7. Verify remote state (before touching local copies)

```bash
terraform plan -lock=false -out=/tmp/post-migration.plan
terraform show -no-color /tmp/post-migration.plan > /tmp/post-migration.txt
diff <(grep -E 'will be|must be|Plan:' /tmp/pre-migration.txt) \
     <(grep -E 'will be|must be|Plan:' /tmp/post-migration.txt)
# Expected: identical action verbs and counts (state preserved exactly).

# Bucket + object checks:
B=jolm-tfstate-production-857941
gcloud storage objects list gs://$B/terraform/production/ --all-versions
gcloud storage buckets describe gs://$B \
  --format='value(default_kms_key_name,versioning.enabled,retention_policy)'
```

Full checklist: `STEP0_VERIFICATION.md`.

## 8. Secure-delete local state (ONLY after step 7 passes)

```bash
cd terraform/environments/production
shred -vzu -n 3 terraform.tfstate terraform.tfstate.backup
# shred caveat: on SSDs wear-leveling may leave copies; full-disk
# encryption (LUKS) is the compensating control. Do NOT `rm` alone.
# Bootstrap local state (terraform/bootstrap/terraform.tfstate.d/*)
# shreds the same way once the window closes.
```

Then: record completion in CHANGELOG.md + change record, remove the
LOCAL BACKEND EXCEPTION block in `scripts/audit-no-secrets.sh` (it exists
only while local state is canonical), and file the follow-up for the WIF
CI binding (`docs/workload-identity-federation.md`) + fleet import.

## 9. Phase B — make the backend permanent (PR, after WIF is live)

Once V1–V8 pass AND `docs/workload-identity-federation.md` setup is done:

1. PR: commit `terraform { backend "gcs" {} }` into both environments'
   `main.tf` (permanent home), set repo var `TF_REMOTE_STATE=true`.
2. Delete the `zz-remote-backend.tmp.tf` overlays on every machine.
3. Watch CI: drift/plan/apply now `init` against GCS via WIF — a red
   run here means the gate was flipped too early (revert the var first).

Until phase B merges, CI keeps dry-planning with `-backend=false`:
expected, documented, temporary.

## Rollback (rehearse on staging first)

Per ADR-0003 "Rollback procedure": temporarily swap the config to
`backend "local"`, `terraform init -migrate-state` to pull state back,
verify plan parity, then treat the GCS copy as retained evidence.
Rollback is a Crit-class change of its own — change record mandatory.

## Incident pointers

- State file seen outside the bucket → `state-compromise.md`.
- KMS key suspected compromised → disable the key version first
  (`gcloud kms keys versions disable`), then `state-compromise.md`.
- Accidental state delete → `terraform/README.md` "State recovery"
  (versioned restore to a NEW object name, never overwrite in place).
