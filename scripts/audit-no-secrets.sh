#!/usr/bin/env bash
# audit-no-secrets.sh — pre-push net. Fails if state files, key material,
# vault password files, or credential-shaped strings appear in the tree.
# Runs locally via `make check` and in CI (.github/workflows/ci.yml).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SELF="$REPO_ROOT/scripts/audit-no-secrets.sh"
cd "$REPO_ROOT"

status=0

# 1) Forbidden file names (state / keys / vault passwords).
while IFS= read -r f; do
  echo "FORBIDDEN FILE: $f"
  status=1
done < <(find . -path ./.git -prune -o \
  \( -name '*.tfstate' -o -name '*.tfstate.*' -o -name '*.tfplan' \
     -o -name '*.pem' -o -name '*.key' -o -name '*.p12' -o -name '*.pfx' \
     -o -name '.vault-pass*' -o -name '*-vault-pass*' -o -name 'vault_pass*' \
     -o -name '.envrc' -o -name 'id_rsa*' -o -name 'id_ed25519*' \) \
  ! -name 'rotate-vault-password.sh' \
  -print 2>/dev/null | grep -v '\.gitkeep' || true)
# Note: rotate-vault-password.sh is the dual-control HELPER, not a password
# file — the only sanctioned exception to the *-vault-pass* pattern.

# 2) Forbidden content patterns. Patterns are built from fragments so this
# script itself never matches its own definitions.
GH="ghp_[A-Za-z0-9]{30,}"
GH2="github_pat_[A-Za-z0-9_]{30,}"
PK="-----BEGIN (RSA|EC|OPENSSH|PGP) PRIVATE KEY"
SLACK="xox[baprs]-[A-Za-z0-9-]{10,}"
AGE="AGE-SECRET-KEY-1[A-Z0-9]{50,}"
TFSTATE_MARK='"terraform_version"[[:space:]]*:'

hits="$(grep -RInE "$GH|$GH2|$PK|$SLACK|$AGE|$TFSTATE_MARK" . \
  --exclude-dir=.git --exclude-dir=.terraform \
  --exclude="$(basename "$SELF")" 2>/dev/null || true)"
if [ -n "$hits" ]; then
  echo "FORBIDDEN CONTENT:"
  echo "$hits"
  status=1
fi

if [ "$status" -eq 0 ]; then
  echo "AUDIT CLEAN: no state, keys, or credential patterns found"
else
  echo "AUDIT FAILED: remove the findings above before pushing (see SECURITY.md)" >&2
fi
exit "$status"
