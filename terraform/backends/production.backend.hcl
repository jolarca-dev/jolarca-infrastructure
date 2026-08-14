# Production backend — GCS remote state.
#
# STATE IS THE CROWN JEWEL. Production state lives in a SEPARATE bucket
# from staging, encrypted with a SEPARATE CMEK key, reachable only by a
# SEPARATE service account (ADR-0002, security/isolation-model.md).
#
# CUSTODY RULES:
#   1. No shared state with staging. Ever.
#   2. CMEK with a production-only key; key custodians listed in
#      security/key-custody.md (dual control).
#   3. Object versioning ON + retention policy; deletion requires the
#      break-glass procedure in terraform/README.md.
#   4. Uniform bucket-level access; audit logging (admin + data read)
#      shipped to the compliance log sink.
#   5. Any state file observed outside this bucket = incident:
#      docs/runbooks/state-compromise.md.
#
# Bucket naming lands with scripts/bootstrap.sh (bucket names are global).
bucket  = "REPLACE_ME-jolm-tfstate-production"
prefix  = "terraform/production"
# CMEK is applied at bucket level by the state-bucket module; never put
# key material in backend config.
