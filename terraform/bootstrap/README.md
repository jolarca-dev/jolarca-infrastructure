# terraform/bootstrap — state-custody bootstrap root

One-time, human-gated root that creates the state buckets themselves via
`modules/state-bucket/`. LOCAL state by design — this is the
chicken-and-egg step of ADR-0003.

## Custody rules

- Run ONLY inside an approved change window (Crit-class, two-person rule).
- One workspace per environment: `terraform workspace select staging` or
  `production`. The workspace precondition refuses anything else.
- Local bootstrap state (`terraform.tfstate.d/<env>.tfstate`) contains
  bucket/KMS metadata only — still treat it as sensitive: encrypted disk,
  never committed (`.gitignore` covers `*.tfstate*`), securely deleted
  once the environment migration is verified.
- `project_id` is supplied at runtime (`TF_VAR_project_id`), never
  committed.

## Usage

See `docs/runbooks/bootstrap-state-backend.md` — that runbook is the
procedure of record; this README only documents the root's contract.
