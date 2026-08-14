#!/usr/bin/env bash
# check-drift.sh — local drift check; SAME logic as drift-detection.yml.
# Usage: scripts/check-drift.sh [staging|production]   (default: production)
# Exit codes: 0 = no drift, 2 = drift present, 1 = error.
# Credentials: GITHUB_TOKEN from the operator environment (never as argv).
set -euo pipefail

ENV_NAME="${1:-production}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="$REPO_ROOT/terraform/environments/$ENV_NAME"

if [ ! -d "$ENV_DIR" ]; then
  echo "unknown environment: $ENV_NAME (expected staging|production)" >&2
  exit 1
fi
command -v terraform >/dev/null 2>&1 || {
  echo "terraform CLI not found" >&2; exit 1;
}
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "warning: GITHUB_TOKEN unset — github provider calls will fail" >&2
fi

cd "$ENV_DIR"
terraform init -backend=false -input=false >/dev/null

set +e
terraform plan -lock=false -input=false -detailed-exitcode
rc=$?
set -e

case "$rc" in
  0) echo "no drift in $ENV_NAME" ;;
  2) echo "DRIFT detected in $ENV_NAME — explain with a change record or treat as incident (SECURITY.md)" >&2 ;;
  *) echo "terraform plan failed (exit $rc)" >&2 ;;
esac
exit "$rc"
