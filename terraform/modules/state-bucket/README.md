# modules/state-bucket — Terraform state custody (ADR-0003)

Provisions the remote-state custody stack for ONE environment per
invocation. Staging and production are applied separately from
`terraform/bootstrap/` with separate workspaces: separate buckets,
separate CMEK keys, separate service accounts (ADR-0002).

## What it creates

| Resource | Purpose |
|---|---|
| KMS keyring + crypto key (`tfstate-<env>`) | CMEK, 90-day rotation, prevent_destroy |
| `google_storage_bucket` | Versioning, uniform access, public-access prevention, soft delete, optional retention lock, prevent_destroy |
| `google_storage_bucket` (logs) | Access/usage log target, CMEK + versioned (CKV_GCP_62) |
| Dedicated SA `tfstate-<env>` | Only state writer; `storage.objectAdmin` on the bucket + KMS encrypterDecrypter; no human members, no basic roles |
| Optional WIF binding | `roles/iam.serviceAccountTokenCreator` for the CI principal (`ci_principal`) |
| GCS audit config | ADMIN_READ + DATA_READ + DATA_WRITE audit logs |

## Inputs (summary)

| Name | Required | Notes |
|---|---|---|
| `environment` | yes | `staging` or `production` |
| `project_id` | yes | Operator-supplied via `TF_VAR_project_id`; never committed |
| `bucket_name` | yes | Globally unique, MUST contain `tfstate` (require-cmek.rego) |
| `region` | no | Default `europe-west1`; must match KMS keyring location |
| `retention_days` | no | 0 = versioning only (staging); production uses 90 |
| `lock_retention` | no | IRREVERSIBLE; production locks after verification |
| `ci_principal` | no | WIF principal for CI impersonation (post-bootstrap) |

## Policy gates

- `policies/require-cmek.rego`: buckets named `*tfstate*` must carry an
  `encryption` block — satisfied by `default_kms_key_name`.
- `policies/no-basic-iam-roles.rego`: only curated roles are bound
  (`storage.objectAdmin`, `cloudkms.cryptoKeyEncrypterDecrypter`,
  `iam.serviceAccountTokenCreator`).

## Bootstrap ordering

This module's own output is where all other state will live, so it is
applied once per environment from `terraform/bootstrap/` with LOCAL state
(the chicken-and-egg step). Procedure of record:
`docs/runbooks/bootstrap-state-backend.md`.
