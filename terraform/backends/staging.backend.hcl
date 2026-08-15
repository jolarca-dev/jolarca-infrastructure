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
# Bucket name is FROZEN (ADR-0003): terraform/bootstrap/main.tf creates
# exactly this bucket; changing one without the other loses state.
bucket  = "jolm-tfstate-staging-3c4a45"
prefix  = "terraform/staging"
# encryption_key is NOT set here: CMEK is applied at bucket level by the
# state-bucket module; putting a key in backend config would be a secret
# in git.
