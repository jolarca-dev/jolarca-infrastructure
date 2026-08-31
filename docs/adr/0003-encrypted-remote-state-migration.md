# ADR-0003: Encrypted remote state migration (local → GCS)

- **Status:** Accepted (STEP 0 directive, 2026-08-15) — implementation in
  progress; two-person sign-off evidence is recorded in `jolarca-compliance`
  when the second operator onboards (solo-era deviation, see ADR-0001
  lineage in `security/key-custody.md`)
- **Date:** 2026-08-14 (proposed) → 2026-08-15 (accepted)
- **Deciders:** org owner (sole operator, solo era)

## Context

State lived on operator machines (implicit local backend) — audit finding
F-05. Acceptable only for bootstrap of the GitHub-org baseline;
unacceptable once real cloud resources exist: unencrypted-at-rest state on
laptop disks is a GDPR Art. 32 and ISO 27001 A.8.24 violation in waiting,
and local state gives no locking (concurrent-apply corruption risk), no
versioning (no undo), and no audit trail (no answer to "who touched state
and when"). Migration is a **Crit-class change** (CONTRIBUTING.md).

## Decision

Migrate each environment to a dedicated GCS backend
(`terraform/backends/*.backend.hcl`), provisioned by the
`modules/state-bucket/` module via the one-time
`terraform/bootstrap/` root:

1. **Separate custody per environment** (ADR-0002): staging and
   production get separate buckets, CMEK keys, and service accounts.
   - `jolm-tfstate-staging-3c4a45` (prefix `terraform/staging`)
   - `jolm-tfstate-production-857941` (prefix `terraform/production`)
   Names are frozen in both `backends/*.backend.hcl` and
   `bootstrap/main.tf`; the `*tfstate*` convention is what
   `policies/require-cmek.rego` keys on.
2. **CMEK**: environment-scoped KMS keyring/key (`tfstate-<env>`),
   90-day rotation, `prevent_destroy`; encrypterDecrypter granted only to
   the GCS service account and the environment's state SA. Revoking the
   key renders leaked state copies unreadable (core mitigation in
   `docs/runbooks/state-compromise.md`).
3. **Bucket hardening**: object versioning, uniform bucket-level access,
   `public_access_prevention = enforced`, 7-day soft delete,
   `prevent_destroy`; production additionally carries a locked 90-day
   retention policy.
4. **Access model**: dedicated `tfstate-<env>` service account
   (`storage.objectAdmin` bucket-scoped) as the only state writer; CI
   reaches it via Workload Identity Federation impersonation
   (`docs/workload-identity-federation.md`) — no SA JSON keys anywhere;
   operators have no direct bucket write outside break-glass.
5. **Audit**: GCS ADMIN_READ/DATA_READ/DATA_WRITE audit logging enabled
   by the module.
6. **Migration order**: staging bucket → staging soak → production, per
   `docs/runbooks/bootstrap-state-backend.md`; every apply human-gated;
   local state securely deleted only after remote verification.
7. **Backend declaration model** (hardened by the PR #5 CI failure):
   configs stay backend-free until migration completes — any declared
   backend breaks `init -backend=false` CI dry plans. The migration
   window uses the gitignored `zz-remote-backend.tmp.tf` overlay; the
   permanent `backend "gcs" {}` blocks land together with the WIF-ready
   `TF_REMOTE_STATE` flip (runbook step 9).

## Alternatives considered

- **HCP Terraform / Terraform Cloud**: managed state + locking, but adds
  a third-party processor holding crown-jewel metadata (GDPR processor
  register, DPA, exit plan), conflicts with the self-hosted doctrine
  (ADR-0001 90/10 split), and costs scale with operators. Rejected;
  revisit if operator count > 3 and the compliance register absorbs a
  new processor.
- **Local state + filesystem encryption (status quo hardened)**: keeps a
  single point of failure per machine, no locking, no versioning, no
  audit trail; fails the ISO 27001 A.8.24 evidence bar. Rejected.
- **Self-hosted S3-compatible (MinIO on bare metal) backend**: fits the
  90% plane, but the Terraform S3 backend would then depend on the very
  infrastructure Terraform provisions (circular bootstrap across planes),
  and MinIO adds its own key/upgrade custody burden before the bare-metal
  plane is built. Rejected for STEP 0; reconsider if the GCP plane is
  ever decommissioned.

## Consequences

- (+) State gains CMEK, versioning, locking, audit logging, independent
  backup, and a documented custody chain.
- (+) CI plans/drift reads real state via WIF — no credentials in CI.
- (−) All operators lose local-state convenience — by design.
- (−) Bootstrap is a one-time manual chicken-and-egg step
  (`terraform/bootstrap/` keeps local state until it is itself retired).
- (−) GCS/KMS become availability-critical for changes (mitigation:
  break-glass procedure in `terraform/README.md`).

## Rollback procedure

Rollback = revert to local backend; rehearse in staging first:

1. `terraform init -migrate-state` after temporarily pointing the config
   at a `backend "local"` — copies remote state back to the machine.
2. Verify `terraform plan` parity, then remove the gcs backend block.
3. Treat the migrated copy in GCS as retained evidence (versioning keeps
   it); do NOT delete the bucket (prevent_destroy will refuse anyway).
4. Rollback is itself a Crit-class change: change record + reason in
   `jolarca-compliance`, and reopen this ADR with a Superseded-by pointer.

## Compliance mapping

SOC 2 CC6.6 (logical access to state), CC7.1 (vulnerability handling of
dependencies via pinned providers), CC8.1 (migration record as change
evidence); ISO 27001 A.8.24 (use of cryptography), A.8.31 (separation of
environments); GDPR Art. 32 (encryption of processing).
