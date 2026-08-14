#!/usr/bin/env bash
# bootstrap.sh — ONE-TIME state custody bootstrap: state buckets, CMEK keys,
# operator IAM. Real provisioning lands with terraform/modules/state-bucket
# (ADR-0003); this script is the guard-railed entry point and checklist.
#
# This is a CRIT-class change: run only inside an approved change window,
# with a second operator present (two-person rule).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIRM_FLAG="${1:-}"

if [ "$CONFIRM_FLAG" != "--i-have-a-second-operator" ]; then
  cat >&2 <<'EOF'
REFUSING TO RUN: bootstrap is a Crit-class change.

Required before running:
  1. Approved change request (issue) with blast radius + rollback plan
  2. A second operator present for the entire window
  3. ADR-0003 accepted (docs/adr/0003-encrypted-remote-state-migration.md)
  4. Re-run with: --i-have-a-second-operator

Procedure of record: terraform/README.md "State bootstrap procedure".
EOF
  exit 1
fi

for env in staging production; do
  backend="$REPO_ROOT/terraform/backends/$env.backend.hcl"
  if grep -q "REPLACE_ME" "$backend"; then
    echo "backend $backend still contains REPLACE_ME placeholders — set bucket names first" >&2
    exit 1
  fi
done

cat <<'EOF'
Bootstrap checklist (execute in order; stop on any failure):

  [ ] 1. GCP project + KMS key rings created (staging and production SEPARATE)
  [ ] 2. terraform/modules/state-bucket applied for staging
         (dedicated bucket, CMEK, versioning, uniform access, audit logs)
  [ ] 3. conftest policy gate passes against the bucket plan (require-cmek)
  [ ] 4. staging backend migrated:
         terraform init -backend-config=...staging.backend.hcl -migrate-state
  [ ] 5. soak period observed; drift check green
  [ ] 6. repeat 2-5 for production with SEPARATE bucket/CMEK/SA
  [ ] 7. backup layer live (backup/terraform-state/README.md)
  [ ] 8. local state copies securely deleted
  [ ] 9. CHANGELOG + compliance evidence updated

Any deviation requires a new change request — do not improvise.
EOF
