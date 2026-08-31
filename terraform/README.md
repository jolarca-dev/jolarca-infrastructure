# terraform/ — IaC for the 10% GCP plane + state custody

## Layout

| Path                | Purpose                                                    |
|---------------------|------------------------------------------------------------|
| `backends/`         | Per-environment GCS backend config (isolated buckets/keys)  |
| `environments/`     | `staging/`, `production/` — one root module per environment |
| `modules/`          | Reusable modules; `github-org/` is live, others reserved    |
| `policies/`         | OPA/Rego policies enforced by Conftest in CI                |

## State bootstrap procedure (ADR-0003)

State migration from local to GCS is a **Crit-class change** (two-person
rule + change window). Procedure of record:
`../docs/runbooks/bootstrap-state-backend.md` with operator gates in
`../STEP0_VERIFICATION.md`. Ordered summary:

1. Apply `bootstrap/` (workspace `staging`) — runs `modules/state-bucket/`:
   dedicated bucket, CMEK, versioning, uniform access, audit logging.
2. Verify `policies/require-cmek.rego` passes against the bucket plan.
3. In `environments/staging`: place the gitignored backend overlay and
   run `terraform init -migrate-state -backend-config=bucket=… …`
   (exact commands: runbook steps 3/6; permanent block lands in phase B).
4. Repeat 1–3 for **production** with its own bucket + CMEK + service
   account. NEVER reuse the staging bucket or key.
5. Import the migrated state into `backup/terraform-state/` procedure.
6. Record the migration in CHANGELOG.md and the change log (SOC 2 CC8.1).

## Break-glass access

Normal path: operators have NO direct bucket or state access; all writes go
through CI with the environment service account.

Break-glass (incident only, e.g. CI down during a live incident):

1. Announce in the operator channel; break-glass is always an audited event.
2. Retrieve the break-glass service-account key from Vaultwarden
   (custodians: see `../security/key-custody.md` — two holders, both must
   concur; record both names + timestamp).
3. Perform the minimal manual operation; export a full plan before/after.
4. Within 24h: rotate the break-glass key, file the event in
   `jolarca-compliance`, and reconcile drift (`../scripts/check-drift.sh`).

## State recovery

State is versioned in GCS. Recovery order:

1. Identify the last good version (`gcloud storage objects list --versions`).
2. Restore to a **new object name** — never overwrite in place.
3. `terraform init -reconfigure`, then `terraform plan` to confirm the
   restored state matches reality; fix residual drift via import, not edits.
4. If state content is suspected leaked: switch to
   `../docs/runbooks/state-compromise.md` immediately.

## Policy enforcement

`make check` and `security-scan.yml` run Conftest against plan JSON:

- `policies/no-public-ips.rego` — no directly internet-addressed compute
- `policies/no-basic-iam-roles.rego` — owner/editor/viewer banned
- `policies/require-cmek.rego` — CMEK on state buckets, GKE secrets encryption

Policy bypass is not a flag: it is a PR to change the policy, reviewed by
`@security` owners.
