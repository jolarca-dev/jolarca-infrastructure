# CI authentication: Workload Identity Federation (ADR-0003)

Doctrine: **no SA JSON keys in CI, ever.** GitHub Actions authenticates
to GCP via Workload Identity Federation (OIDC), impersonates the
environment's state service account, and Terraform's GCS backend runs as
that SA. Short-lived tokens only; attribution stays per-repo/per-ref.

Status: **setup pending** — the pool/provider below is created once the
state buckets exist (post-bootstrap). Workflows are already wired behind
the `TF_REMOTE_STATE` repository variable gate (default off), so nothing
calls GCP until this lands.

## 1. One-time GCP setup (operator, change window)

```bash
P=<PROJECT_ID>; POOL=github-actions; PROVIDER=jolm-infra

gcloud iam workload-identity-pools create "$POOL" \
  --location=global --display-name="GitHub Actions (jolarca-infrastructure)"

gcloud iam workload-identity-pools providers create-oidc "$PROVIDER" \
  --location=global --workload-identity-pool="$POOL" \
  --display-name="jolarca-infrastructure repo" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref,attribute.actor=assertion.actor"
```

## 2. Attribute condition (pin WHO may federate)

Never bind the whole issuer. The condition pins repository — and for
apply-grade access, the ref:

```
attribute.repository == "journeyoflife-org/jolarca-infrastructure"
```

For production state access, additionally restrict on the principal-set
binding below to `attribute.ref == "refs/heads/main"` (applies run from
main/dispatch only; PR plans stay read-scoped).

## 3. Bind the CI principal to the state SA

The state-bucket module owns this binding via `ci_principal` — re-run the
bootstrap root with the variable once the pool exists:

```
principalSet://iam.googleapis.com/projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github-actions/attribute.repository/journeyoflife-org/jolarca-infrastructure
```

That grants `roles/iam.serviceAccountTokenCreator` on
`tfstate-<env>@...` — CI can impersonate, nothing more.

## 4. GitHub repository variables (NOT secrets — identifiers)

| Variable | Value |
|---|---|
| `TF_REMOTE_STATE` | `true` (flipped AFTER migration verified — CI gate) |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/<NUM>/locations/global/workloadIdentityPools/github-actions/providers/jolm-infra` |
| `GCP_STATE_SA_STAGING` | `tfstate-staging@<PROJECT>.iam.gserviceaccount.com` |
| `GCP_STATE_SA_PRODUCTION` | `tfstate-production@<PROJECT>.iam.gserviceaccount.com` |

## 5. How workflows use it

`drift-detection.yml` and `terraform.yml` (apply job) run, only when
`TF_REMOTE_STATE == 'true'`:

1. `google-github-actions/auth` (SHA-pinned) exchanges the GitHub OIDC
   token for GCP credentials under the attribute condition above.
2. `terraform init -backend-config=bucket=<bucket>`
   `-backend-config=prefix=terraform/<env>`
   `-backend-config=impersonate_service_account=<state SA>` — the state
   SA is the only identity that writes state. (The permanent
   `backend "gcs" {}` blocks exist since the runbook phase-B PR.)

Until `TF_REMOTE_STATE` flips, both workflows keep today's
`-backend=false` behavior — CI never silently runs against empty state
pretending it is drift-free.

## Incident pointers

- Federated token misuse suspected → revoke by deleting the binding in
  step 3 (instant) and review Cloud Audit Logs for
  `sts.googleapis.com` + `storage.googleapis.com` DATA_READ events.
- State exposure → `docs/runbooks/state-compromise.md` (CMEK revocation
  is the kill switch).
