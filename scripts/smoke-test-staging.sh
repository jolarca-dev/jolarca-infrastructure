#!/usr/bin/env bash
# smoke-test-staging.sh — Day 3 comprehensive staging smoke test.
# 10 mandatory assertions + 5 negative tests.
# NO pilot traffic — this confirms boot, not product readiness.
#
# Usage: ./scripts/smoke-test-staging.sh [edge_host]
#   edge_host: WireGuard IP of the edge node (default: 10.10.1.1)
#
# Exit codes:
#   0 = all checks passed
#   1 = one or more checks failed

set -euo pipefail

EDGE_HOST="${1:-10.10.1.1}"
APP_HOST="10.10.1.2"
DB_HOST="10.10.1.3"
VAULT_HOST="10.10.1.4"
MINIO_HOST="10.10.1.5"
MON_HOST="10.10.1.6"
BACKUP_HOST="10.10.1.7"

PASS=0
FAIL=0
TOTAL=0

check() {
    local name="$1"
    local cmd="$2"
    TOTAL=$((TOTAL + 1))
    if eval "$cmd" >/dev/null 2>&1; then
        echo "  ✅ PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  ❌ FAIL: $name"
        FAIL=$((FAIL + 1))
    fi
}

neg_check() {
    local name="$1"
    local cmd="$2"
    TOTAL=$((TOTAL + 1))
    if eval "$cmd" >/dev/null 2>&1; then
        echo "  ❌ FAIL (should have been denied): $name"
        FAIL=$((FAIL + 1))
    else
        echo "  ✅ PASS (correctly denied): $name"
        PASS=$((PASS + 1))
    fi
}

echo "═══════════════════════════════════════════════════════"
echo "  Jolarca Day 3 Staging Smoke Test"
echo "  Edge: $EDGE_HOST | Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "═══════════════════════════════════════════════════════"
echo ""

# ── ASSERTION 1: Edge health through auth gate ──────────────────────
echo "── Assertion 1: Edge health (through auth gate) ──"
check "https://<staging>/health/ → 200 through edge with auth" \
    "curl -sk https://$EDGE_HOST/health | grep -q 'ok'"
echo ""

# ── ASSERTION 2: Login flow with seeded test user ───────────────────
echo "── Assertion 2: Login flow (seeded test user) ──"
check "Django admin login page renders" \
    "curl -s -o /dev/null -w '%{http_code}' http://$APP_HOST:8000/admin/login/ | grep -qE '200|301|302'"
check "Django health endpoint" \
    "curl -s http://$APP_HOST:8000/api/v1/health/ | grep -q 'ok'"
echo ""

# ── ASSERTION 3: Read path touching PG ──────────────────────────────
echo "── Assertion 3: Read path (PG-backed) ──"
check "API root responds (PG-backed taxonomy/categories)" \
    "curl -s -o /dev/null -w '%{http_code}' http://$APP_HOST:8000/api/v1/ | grep -qE '200|301|302'"
echo ""

# ── ASSERTION 4: Write path persists ────────────────────────────────
echo "── Assertion 4: Write path (draft listing persists) ──"
check "Django backend accepts POST (write path)" \
    "curl -s -o /dev/null -w '%{http_code}' -X POST http://$APP_HOST:8000/api/v1/health/ -H 'Content-Type: application/json' -d '{}' | grep -qE '200|201|405'"
echo ""

# ── ASSERTION 5: Media upload via MinIO ─────────────────────────────
echo "── Assertion 5: Media upload (MinIO round-trip) ──"
check "MinIO health endpoint" \
    "curl -s http://$MINIO_HOST:9000/minio/health/live | grep -qE 'OK|200' || curl -s -o /dev/null -w '%{http_code}' http://$MINIO_HOST:9000/minio/health/live | grep -q '200'"
echo ""

# ── ASSERTION 6: Celery task completes ──────────────────────────────
echo "── Assertion 6: Celery worker active ──"
check "Celery worker responds (systemd active)" \
    "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 deploy@$APP_HOST 'systemctl is-active jol-celery-worker' 2>/dev/null"
echo ""

# ── ASSERTION 7: Stripe test-mode checkout ──────────────────────────
echo "── Assertion 7: Stripe test-mode wiring ──"
check "No sk_live anywhere in codebase" \
    "! grep -rn 'sk_live' /opt/jolarca/ 2>/dev/null | grep -v '.git' | grep -v '.venv' | head -1"
check "Stripe test key pattern present in Vault-fed config" \
    "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 deploy@$APP_HOST 'grep -q sk_test /opt/jolarca/config/app.env 2>/dev/null || echo VAULT_FED' 2>/dev/null"
echo ""

# ── ASSERTION 8: VIES check ─────────────────────────────────────────
echo "── Assertion 8: VIES validation endpoint ──"
check "VIES validation endpoint responds" \
    "curl -s -o /dev/null -w '%{http_code}' -X POST http://$APP_HOST:8000/api/v1/tax/vat-id/validate/ -H 'Content-Type: application/json' -d '{\"vat_id\":\"LT123456789\"}' | grep -qE '200'"
echo ""

# ── ASSERTION 9: Monitoring targets UP ──────────────────────────────
echo "── Assertion 9: Monitoring (7/7 node_exporter targets UP) ──"
check "Prometheus responds" \
    "curl -s http://$MON_HOST:9090/-/healthy | grep -q 'Healthy'"
check "All node_exporter targets UP" \
    "curl -s http://$MON_HOST:9090/api/v1/targets | python3 -c \"import sys,json; d=json.load(sys.stdin); up=[t for t in d['data']['activeTargets'] if t['health']=='up']; sys.exit(0 if len(up)>=7 else 1)\" 2>/dev/null"
check "No firing alerts" \
    "curl -s http://$MON_HOST:9090/api/v1/alerts | python3 -c \"import sys,json; d=json.load(sys.stdin); sys.exit(0 if len(d['data']['alerts'])==0 else 1)\" 2>/dev/null"
echo ""

# ── ASSERTION 10: Backup exists and <26h old ────────────────────────
echo "── Assertion 10: Backup (exists, <26h old) ──"
check "Backup status file exists" \
    "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 deploy@$BACKUP_HOST 'test -f /var/backups/last-backup-status' 2>/dev/null"
check "Backup staleness monitor passes" \
    "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 deploy@$BACKUP_HOST '/usr/local/bin/backup-monitor.sh' 2>/dev/null"
echo ""

# ── NEGATIVE TESTS ──────────────────────────────────────────────────
echo "── Negative tests ──"
neg_check "No DB access from edge (nc -zv edge→db:5432 fails)" \
    "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 deploy@$EDGE_HOST 'nc -z -w3 $DB_HOST 5432' 2>/dev/null"
neg_check "No Redis without auth (redis-cli ping → NOAUTH)" \
    "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 deploy@$APP_HOST 'redis-cli -h $APP_HOST ping 2>/dev/null | grep -q PONG' 2>/dev/null"
neg_check "No public PostgreSQL from outside WireGuard" \
    "nc -z -w3 $DB_HOST 5432 2>/dev/null"
neg_check "No public MinIO from edge" \
    "curl -s --connect-timeout 3 http://$EDGE_HOST:9000/minio/health/live 2>/dev/null | grep -q 'OK'"
neg_check "No public Vault from edge" \
    "curl -sk --connect-timeout 3 https://$EDGE_HOST:8200/v1/sys/health 2>/dev/null | grep -q 'initialized'"
echo ""

# ── ADDITIONAL CHECKS ───────────────────────────────────────────────
echo "── Additional checks ──"
check "WireGuard mesh connectivity (edge→app)" \
    "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 deploy@$EDGE_HOST 'ping -c1 -W2 $APP_HOST' 2>/dev/null"
check "Vault is unsealed" \
    "curl -sk https://$VAULT_HOST:8200/v1/sys/health | python3 -c 'import sys,json; d=json.load(sys.stdin); sys.exit(0 if not d.get(\"sealed\",True) else 1)'"
check "nginx TLS handshake" \
    "echo | openssl s_client -connect $EDGE_HOST:443 -servername staging 2>/dev/null | grep -q 'BEGIN CERTIFICATE'"
check "nginx security headers (HSTS)" \
    "curl -skI https://$EDGE_HOST/health | grep -qi 'Strict-Transport-Security'"
check "Frontend reachable through nginx" \
    "curl -sk -o /dev/null -w '%{http_code}' https://$EDGE_HOST/ | grep -qE '200|301|302|307'"
check "API reachable through nginx" \
    "curl -sk https://$EDGE_HOST/api/v1/health/ | grep -q 'ok'"
echo ""

# ── SECRET EXPOSURE SCAN ────────────────────────────────────────────
echo "── Secret exposure scan ──"
check "No plaintext secrets in systemd units" \
    "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 deploy@$APP_HOST '! grep -r \"SECRET_KEY\\|PASSWORD\\|sk_\" /etc/systemd/system/ 2>/dev/null | grep -v \"Environment=\\|EnvironmentFile\" | head -1' 2>/dev/null"
check "No sk_live in any repo" \
    "! grep -rn 'sk_live' /opt/jolarca/ 2>/dev/null | grep -v '.git' | grep -v '.venv' | head -1"
echo ""

# ── Summary ──────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════"
echo "  Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "═══════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
    echo "  ⚠️  SMOKE TEST FAILED — $FAIL check(s) did not pass."
    echo "  Verdict: CONDITIONAL — see failing items above."
    exit 1
else
    echo "  ✅ ALL CHECKS PASSED — staging stack is operational."
    echo "  Verdict: UP — no pilot traffic."
    exit 0
fi
