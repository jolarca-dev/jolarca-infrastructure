#!/usr/bin/env bash
# sync-hv-to-av.sh — One-time sync from HashiCorp Vault to Ansible-Vault.
#
# Reads secrets from HV, writes an ansible-vault encrypted file.
# Uses a short-lived HV token that is revoked after sync.
#
# Prerequisites:
#   - vault CLI installed and authenticated
#   - ansible-vault installed
#   - HV token with read access to secret/data/jolarca/staging/*
#
# Usage:
#   export VAULT_TOKEN=<short-lived-token>
#   ./scripts/sync-hv-to-av.sh [environment]
#
# The AV password is retrieved from HV at secret/data/jolarca/ops/ansible-vault-password

set -euo pipefail

ENVIRONMENT="${1:-staging}"
AV_FILE="ansible/inventories/${ENVIRONMENT}/artifacts/vault-secrets.yml"
AV_PASSWORD_PATH="secret/data/jolarca/ops/ansible-vault-password"
HV_SECRET_PATH="secret/data/jolarca/${ENVIRONMENT}"

echo "═══ HashiCorp Vault → Ansible-Vault Sync ═══"
echo "Environment: ${ENVIRONMENT}"
echo "Target file: ${AV_FILE}"
echo ""

# ── Pre-flight checks ──────────────────────────────────────────────

if [ -z "${VAULT_TOKEN:-}" ]; then
  echo "❌ VAULT_TOKEN not set. Export a short-lived HV token first."
  exit 1
fi

if ! command -v vault &>/dev/null; then
  echo "❌ vault CLI not found. Install from https://www.vaultproject.io/downloads"
  exit 1
fi

if ! command -v ansible-vault &>/dev/null; then
  echo "❌ ansible-vault not found. Install ansible-core."
  exit 1
fi

# Verify token is valid
vault token lookup &>/dev/null || {
  echo "❌ VAULT_TOKEN is invalid or expired"
  exit 1
}

echo "✅ Vault token valid"

# ── Retrieve AV password from HV ────────────────────────────────────

echo "Retrieving Ansible-Vault password from HV..."
AV_PASSWORD=$(vault kv get -field=password "${AV_PASSWORD_PATH}" 2>/dev/null) || {
  echo "❌ Cannot read AV password from ${AV_PASSWORD_PATH}"
  echo "   Ensure the 'ops' policy grants read access."
  exit 1
}

echo "✅ AV password retrieved"

# ── Read secrets from HV ────────────────────────────────────────────

echo "Reading secrets from HV at ${HV_SECRET_PATH}..."

DB_PASSWORD=$(vault kv get -field=db_password "${HV_SECRET_PATH}" 2>/dev/null || echo "")
DJANGO_SECRET_KEY=$(vault kv get -field=django_secret_key "${HV_SECRET_PATH}" 2>/dev/null || echo "")
REDIS_PASSWORD=$(vault kv get -field=redis_password "${HV_SECRET_PATH}" 2>/dev/null || echo "")
MINIO_ACCESS_KEY=$(vault kv get -field=minio_access_key "${HV_SECRET_PATH}" 2>/dev/null || echo "")
MINIO_SECRET_KEY=$(vault kv get -field=minio_secret_key "${HV_SECRET_PATH}" 2>/dev/null || echo "")
STRIPE_SECRET_KEY=$(vault kv get -field=stripe_secret_key "${HV_SECRET_PATH}" 2>/dev/null || echo "")
STRIPE_PUBLISHABLE_KEY=$(vault kv get -field=stripe_publishable_key "${HV_SECRET_PATH}" 2>/dev/null || echo "")

# Verify we got at least some secrets
if [ -z "${DB_PASSWORD}" ] && [ -z "${DJANGO_SECRET_KEY}" ]; then
  echo "❌ No secrets found at ${HV_SECRET_PATH}"
  echo "   Populate HV first, then re-run this script."
  exit 1
fi

echo "✅ Secrets read from HV"

# ── Write Ansible-Vault file ────────────────────────────────────────

mkdir -p "$(dirname "${AV_FILE}")"

echo "Writing Ansible-Vault file..."

cat > /tmp/av-plaintext.yml << EOF
# Ansible-Vault encrypted secrets — synced from HashiCorp Vault
# Source: ${HV_SECRET_PATH}
# Synced: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# DO NOT edit manually — re-run sync-hv-to-av.sh to update

vault_pg_app_password: "${DB_PASSWORD}"
vault_django_secret_key: "${DJANGO_SECRET_KEY}"
vault_redis_password: "${REDIS_PASSWORD}"
vault_minio_access_key: "${MINIO_ACCESS_KEY}"
vault_minio_secret_key: "${MINIO_SECRET_KEY}"
vault_stripe_secret_key: "${STRIPE_SECRET_KEY}"
vault_stripe_publishable_key: "${STRIPE_PUBLISHABLE_KEY}"
EOF

# Encrypt with ansible-vault
echo "${AV_PASSWORD}" | ansible-vault encrypt /tmp/av-plaintext.yml --output "${AV_FILE}" --vault-password-file /dev/stdin

# Clean up plaintext
rm -f /tmp/av-plaintext.yml

echo "✅ Ansible-Vault file written: ${AV_FILE}"

# ── Revoke the HV token ────────────────────────────────────────────

echo "Revoking HV token..."
vault token revoke "${VAULT_TOKEN}" 2>/dev/null || echo "⚠️  Token revocation failed (may already be expired)"
unset VAULT_TOKEN
unset AV_PASSWORD

echo "✅ Token revoked"

# ── Verify ──────────────────────────────────────────────────────────

echo ""
echo "═══ Verification ═══"
echo "File exists: $(test -f "${AV_FILE}" && echo '✅' || echo '❌')"
echo "File is encrypted: $(head -1 "${AV_FILE}" | grep -q 'ANSIBLE_VAULT' && echo '✅' || echo '❌')"
echo "File is gitignored: $(git check-ignore "${AV_FILE}" &>/dev/null && echo '✅' || echo '❌')"

echo ""
echo "═══ Sync Complete ═══"
echo "Run playbooks with:"
echo "  echo \"\$(vault kv get -field=password ${AV_PASSWORD_PATH})\" | \\"
echo "    ansible-playbook playbooks/65-app.yml \\"
echo "    -i inventories/${ENVIRONMENT}/hosts.yml \\"
echo "    --vault-password-file /dev/stdin"
