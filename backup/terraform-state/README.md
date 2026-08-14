# Terraform state backup procedure

Bucket object versioning (ADR-0002) is the first layer; this procedure is
the second, independent layer (ISO 27001 A.8.13 redundancy of information
processing facilities).

## Procedure (lands with the state-migration workstream)

1. **Daily**: GCS `storage.objects.copy` of each environment's latest
   state object to the backup bucket (separate project, separate CMEK,
   separate region pair), retaining 30 daily + 12 monthly versions.
2. Copy runs as a scheduled CI job with its own read+write SA — the job
   token has NO access to the live state buckets' write path.
3. Every copy logs source object generation + hash to the compliance log
   sink (evidence for CC7.3 monitoring).

## Restore

1. Declare the restoration reason (drift recovery vs compromise response —
   different runbooks: `../../terraform/README.md` vs
   `../../docs/runbooks/state-compromise.md`).
2. Restore to a NEW object name; never overwrite the live object directly.
3. Two-person sign-off before `terraform init -reconfigure` repoints.
4. Full `terraform plan` diff after restore; archive it as change evidence.

## Test cadence

Restore-to-a-scratch-bucket is exercised in the quarterly drill
(`../restore-drill.md`). Untested state backups are not backups.
