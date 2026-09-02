#!/usr/bin/env bash
# check-fleet-separation.sh — ADR-0004 guard: marketplace fleet integrity.
#
# The org hosts TWO projects that must never mix (ADR-0004):
#   - mission platform  : jol-*   (out of this repo's jurisdiction)
#   - marketplace       : jolarca* (this module's fleet, PCI-DSS scope)
#
# This guard FAILS when:
#   1. a fleet-map key doesn't match jolarca* naming (defense in depth
#      next to the module's variable validation), or
#   2. an org repo named jolarca* is NOT in the terraform fleet map —
#      out-of-band marketplace repo creation is an INCIDENT: import into
#      terraform within 48h (ADR-0004 R2), or
#   3. a fleet-map repo is missing from the org.
#
# Usage: scripts/check-fleet-separation.sh
# Auth: gh CLI token (GH_TOKEN / GITHUB_TOKEN) with org repo read.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLEET_TF="$REPO_ROOT/terraform/modules/github-org/variables.tf"
ORG="jolarca-dev"

# Fleet map keys: ALL 4-space-indented `name = {` entries of variable
# "repositories" (terraform-fmt-canonical indentation; 2-space lines like
# `default = {` and 6-space object attributes are excluded by the regex).
# Non-jol-m-* keys are intentionally parsed so the R1 check can flag them.
fleet="$(sed -nE 's/^    ([a-z0-9-]+) = \{$/\1/p' "$FLEET_TF" | sort)"
if [ -z "$fleet" ]; then
  echo "ERROR: could not parse the fleet map from $FLEET_TF" >&2
  exit 1
fi

status=0

# R1 defense in depth: every fleet key carries the marketplace prefix.
while IFS= read -r name; do
  case "$name" in
    jolarca|jolarca-*) ;;
    *)
      echo "VIOLATION: fleet key '$name' doesn't match jolarca* naming (ADR-0004 R1)"
      status=1
      ;;
  esac
done <<< "$fleet"

# Org listing of marketplace repos (read-only).
org_m="$(gh api "orgs/$ORG/repos" --paginate -q '.[].name' | grep '^jolarca' | sort)"

# R2: out-of-band marketplace repos (present in org, absent from fleet).
while IFS= read -r name; do
  [ -z "$name" ] && continue
  if ! grep -qx "$name" <<< "$fleet"; then
    echo "VIOLATION: org repo '$name' is jolarca* but NOT in the terraform fleet map."
    echo "  -> out-of-band creation is an incident (ADR-0004 R2): import within 48h."
    status=1
  fi
done <<< "$org_m"

# Fleet repos missing from the org (state drift / deletion).
while IFS= read -r name; do
  if ! grep -qx "$name" <<< "$org_m"; then
    echo "VIOLATION: fleet repo '$name' not found in org '$ORG'."
    status=1
  fi
done <<< "$fleet"

if [ "$status" -eq 0 ]; then
  echo "FLEET SEPARATION OK: org jolarca* set == terraform fleet map ($(grep -c . <<< "$fleet") repos)."
fi
exit "$status"
