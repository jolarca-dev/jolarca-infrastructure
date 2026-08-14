# Staging backend — GCS remote state.
#
# STATE CUSTODY RULES (ADR-0002, security/key-custody.md):
#   1. Dedicated bucket for staging; NEVER shared with production.
#   2. CMEK encryption with a staging-only key (require-cmek.rego enforces
#      CMEK on storage buckets).
#   3. Object versioning ON — versioned state is the undo lever.
#   4. Uniform bucket-level access; no per-object ACLs.
#   5. Access via a staging-only service account; operators get no direct
#      bucket write outside break-glass.
#
# Bucket naming lands with scripts/bootstrap.sh (bucket names are global).
bucket  = "REPLACE_ME-jolm-tfstate-staging"
prefix  = "terraform/staging"
# encryption_key is NOT set here: CMEK is applied at bucket level by the
# state-bucket module; putting a key in backend config would be a secret
# in git.
