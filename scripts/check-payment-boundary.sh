#!/usr/bin/env bash
# check-payment-boundary.sh — ADR-0005 guard (E1): PCI boundary containment.
#
# Model A keeps jol-hub OUT of PCI scope: the marketplace payments_app is
# the sole Stripe integrator, hub consumes the internal payment API only
# (docs/payment-api-contract.md). This guard FAILS when the checked tree
# shows hub reaching for Stripe directly.
#
# Layers (integration markers only — see exemption policy below):
#   1. SERVER SCOPE (python code): Stripe SDK imports/use, Stripe keys,
#      STRIPE_SECRET/STRIPE_API_KEY settings, api.stripe.com.
#   2. MANIFESTS (requirements/lock/pyproject): any stripe declaration —
#      the CI twin of the dependency-guard test (ADR-0005 E2).
#   3. FULL TREE: secret-key material and Stripe server endpoints are
#      forbidden ANYWHERE (incl. frontend/config), because hub has no
#      legitimate server-side Stripe endpoint. js.stripe.com (browser-only
#      Elements include, SAQ-A) is the single sanctioned Stripe artifact
#      in hub and is NOT matched.
#   4. FRONTEND SCOPE (ts/tsx/js/jsx under frontend/apps + frontend/packages):
#      PSP client-SDK imports and key envs are forbidden in hub source —
#      checkout handoffs (redirect) are the ONLY sanctioned pattern
#      (O-021 disposition; donation-flow-spec §1). Exemptions: VOCAB/RULEDOC
#      ledgers only (ADR-010 discipline); no new exemption class.
#
# Exemption policy (each is a NAMED exemption; additions require an ADR):
#   - dependency trees (venv/.venv/node_modules/...): pinned third-party
#     noise (allauth's bundled social provider, scanner corpora); E2
#     governs which packages may be installed.
#   - guard/sentry test files: their CONTENT is the test fixture
#     (test_dependency_guard.py, test_compliance.py, this script).
#   - ledger vocabulary files: the literal string 'stripe' as an
#     accounting/CRM source LABEL is business vocabulary, not an
#     integration (crm models+migration+serializer, bitrix24 deal-source
#     enum, entity-config method validator). Layer 1/2/3 markers still
#     apply inside them — only quoted-label occurrences are exempt.
#   - rule documents (RULEDOC ledger; jol-hub ADR-010, approved per
#     O-017(3)/D-016): a governance rule must NAME the forbidden literals
#     in the sentence that forbids them. ONLY the exact files listed in
#     RULEDOC are exempt from layer-3 literal hits; layers 1/2 unchanged.
#     Additions to RULEDOC require an ADR — no blanket doc exemption.
#
# This file is the RECORD COPY (jolarca-infrastructure); hub CI pins a copy
# of it. Adding any other exception requires an ADR, not a code change.
#
# Usage: scripts/check-payment-boundary.sh [ROOT]
#        (default ROOT: /opt/jol/repos/jol-hub)
set -euo pipefail

ROOT="${1:-/opt/jol/repos/jol-hub}"
SELF="$(basename "${BASH_SOURCE[0]}")"
EXCLUDES=(--exclude-dir=venv --exclude-dir=.venv --exclude-dir=node_modules
          --exclude-dir=.git --exclude-dir=.next --exclude-dir=__pycache__)
FIXTURES=(--exclude=test_dependency_guard.py --exclude=test_compliance.py
          --exclude="$SELF" --exclude='*.tsbuildinfo' --exclude-dir=.next)
# Ledger-vocabulary exemption list (relative to ROOT).
VOCAB=(
  "backend/django/apps/crm/models.py"
  "backend/django/apps/crm/migrations/0001_initial.py"
  "backend/django/apps/crm/api/serializers.py"
  "backend/integrations/bitrix24/api/deals.py"
  "scripts/validate_entity_configs.py"
)
# Rule-document exemption ledger (ADR-010 in jol-hub; O-017(3)/D-016).
# Named scope, exact paths only; adding an entry REQUIRES an ADR.
RULEDOC=(
  "QODER.md"
)

if [ ! -d "$ROOT" ]; then
  echo "ERROR: target tree '$ROOT' not found (pass the hub checkout as \$1)." >&2
  exit 1
fi

status=0

scan() {
  # scan <label> <grep-args...> -- <pattern...>
  local label="$1"; shift
  local grep_args=()
  while [ "$1" != "--" ]; do grep_args+=("$1"); shift; done
  shift
  local p hits
  for p in "$@"; do
    if hits="$(grep -rIn "${grep_args[@]}" "${EXCLUDES[@]}" "${FIXTURES[@]}" \
                 -E "$p" "$ROOT" 2>/dev/null)"; then
      echo "VIOLATION [$label]: pattern '$p' found (ADR-0005 Model A):"
      printf '%s\n' "$hits" | sed 's/^/  /'
      status=1
    fi
  done
}

ledger_excluded() {
  # true (0) when every violating file sits on a named exemption ledger:
  # VOCAB (business label vocabulary) or RULEDOC (rule documents, ADR-010).
  local f rel v
  while IFS= read -r f; do
    rel="${f%%:*}"; rel="${rel#"$ROOT"/}"
    local exempt=1
    for v in "${VOCAB[@]}"; do
      [ "$rel" = "$v" ] && exempt=0 && break
    done
    if [ "$exempt" -eq 1 ]; then
      for v in "${RULEDOC[@]}"; do
        [ "$rel" = "$v" ] && exempt=0 && break
      done
    fi
    [ "$exempt" -eq 1 ] && return 1
  done <<< "$1"
  return 0
}

scan_vocab_aware() {
  # Like scan, but hits confined to named-ledger files are exempt.
  local label="$1"; shift
  local grep_args=()
  while [ "$1" != "--" ]; do grep_args+=("$1"); shift; done
  shift
  local p hits
  for p in "$@"; do
    if hits="$(grep -rIn "${grep_args[@]}" "${EXCLUDES[@]}" "${FIXTURES[@]}" \
                 -E "$p" "$ROOT" 2>/dev/null)"; then
      if ! ledger_excluded "$hits"; then
        echo "VIOLATION [$label]: pattern '$p' found (ADR-0005 Model A):"
        printf '%s\n' "$hits" | sed 's/^/  /'
        status=1
      fi
    fi
  done
}

# Layer 1 — server-side python code: SDK usage, keys, server endpoints.
scan "server-scope" \
  --include='*.py' -- \
  '^[[:space:]]*import[[:space:]]+stripe\b' \
  '^[[:space:]]*from[[:space:]]+stripe\b' \
  '\bstripe\.[A-Za-z_]' \
  'STRIPE_SECRET' 'STRIPE_API_KEY' \
  '\bsk_(live|test)_[A-Za-z0-9]{8,}' \
  '\brk_(live|test)_[A-Za-z0-9]{8,}' \
  'api\.stripe\.com'

# Layer 2 — dependency manifests: any stripe package declaration.
scan "manifests" \
  --include='requirements*.txt' --include='*.toml' --include='*.cfg' \
  --include='pyproject*.toml' -- \
  '^[[:space:]]*stripe([=<>!~\[ ]|$)' \
  '"stripe"' "'stripe'"

# Layer 3 — the whole tree: key material and Stripe server endpoints are
# forbidden anywhere (named-ledger occurrences exempted by VOCAB/RULEDOC).
scan_vocab_aware "full-tree" \
  -I -- \
  '\bsk_(live|test)_[A-Za-z0-9]{8,}' \
  '\brk_(live|test)_[A-Za-z0-9]{8,}' \
  '\bwhsec_[A-Za-z0-9]{8,}' \
  'STRIPE_SECRET' 'STRIPE_API_KEY' \
  'api\.stripe\.com' 'hooks\.stripe\.com'

# Layer 4 — frontend source: PSP client-SDK imports + key envs are forbidden
# in hub (Model A: checkout handoff is the only sanctioned pattern, O-021).
# Scope limited to hub-owned frontend source trees; exemption ledgers apply.
FRONTEND_DIRS=()
[ -d "$ROOT/frontend/apps" ] && FRONTEND_DIRS+=("$ROOT/frontend/apps")
[ -d "$ROOT/frontend/packages" ] && FRONTEND_DIRS+=("$ROOT/frontend/packages")
if [ "${#FRONTEND_DIRS[@]}" -gt 0 ]; then
  scan_frontend() {
    local label="$1"; shift
    local p hits
    for p in "$@"; do
      if hits="$(grep -rIn "${EXCLUDES[@]}" "${FIXTURES[@]}" \
                   --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
                   -E "$p" "${FRONTEND_DIRS[@]}" 2>/dev/null)"; then
        if ! ledger_excluded "$hits"; then
          echo "VIOLATION [$label]: pattern '$p' found (ADR-0005 Model A):"
          printf '%s\n' "$hits" | sed 's/^/  /'
          status=1
        fi
      fi
    done
  }
  scan_frontend "frontend-psp" \
    '@stripe/stripe-js' '@stripe/react-stripe-js' \
    '\bloadStripe\(' 'NEXT_PUBLIC_STRIPE_' \
    '@paypal/react-paypal-js' 'braintree-web' \
    '@adyen/adyen-web' '@mollie/'
fi

if [ "$status" -eq 0 ]; then
  echo "PAYMENT BOUNDARY OK: no Stripe SDK, keys, or server endpoints in '$ROOT'."
fi
exit "$status"
