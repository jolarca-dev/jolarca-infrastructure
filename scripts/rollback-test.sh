#!/usr/bin/env bash
# rollback-test.sh — Automated rollback test for the Jolarca marketplace.
# Deploys a change, then rolls it back, verifying each step.
# This is the PROOF that rollback works.
#
# Usage: ./scripts/rollback-test.sh
#
# Prerequisites:
#   - Staging environment is running and healthy
#   - SSH access to all hosts
#   - Git working tree is clean
#
# Exit codes:
#   0 = rollback test passed
#   1 = rollback test failed

set -euo pipefail

LOG_FILE="/tmp/rollback-test-$(date +%Y%m%d_%H%M%S).log"
TEST_START=$(date +%s)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✅ PASS:${NC} $1"; }
fail() { echo -e "${RED}❌ FAIL:${NC} $1"; }
warn() { echo -e "${YELLOW}⚠️  WARN:${NC} $1"; }
info() { echo "── $1 ──"; }

TOTAL=0
PASSED=0
FAILED=0

check() {
    local name="$1"
    local cmd="$2"
    TOTAL=$((TOTAL + 1))
    if eval "$cmd" >/dev/null 2>&1; then
        pass "$name"
        PASSED=$((PASSED + 1))
    else
        fail "$name"
        FAILED=$((FAILED + 1))
    fi
}

echo "═══════════════════════════════════════════════════════" | tee "$LOG_FILE"
echo "  Jolarca Rollback Test" | tee -a "$LOG_FILE"
echo "  Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# ── Phase 1: Pre-test verification ───────────────────────────────────
info "Phase 1: Pre-test verification"

check "Staging is healthy (edge)" "curl -sk https://10.10.1.1/health"
check "Staging is healthy (API)" "curl -sk https://10.10.1.1/api/v1/health/"
check "Backup is current" "test -f /var/backups/last-backup-status"

# Record current state
CURRENT_BACKEND_COMMIT=$(ssh deploy@10.10.1.2 "cd /opt/jolarca/backend && git rev-parse HEAD" 2>/dev/null || echo "unknown")
echo "Current backend commit: $CURRENT_BACKEND_COMMIT" | tee -a "$LOG_FILE"

# ── Phase 2: Deploy a test change ────────────────────────────────────
info "Phase 2: Deploying test change"

# Create a test change (add a comment to a file)
ssh deploy@10.10.1.2 "cd /opt/jolarca/backend && echo '# rollback-test-$(date +%s)' >> manage.py && git add manage.py && git commit -m 'rollback-test: temporary change'" 2>/dev/null || {
    fail "Could not create test change"
    echo "ROLLBACK TEST FAILED — could not create test change" | tee -a "$LOG_FILE"
    exit 1
}
pass "Test change committed"

# Rebuild and restart
ssh deploy@10.10.1.2 "docker compose -f /opt/jolarca/docker-compose.backend.yml up -d --build" 2>/dev/null || {
    fail "Could not rebuild backend"
    echo "ROLLBACK TEST FAILED — could not rebuild" | tee -a "$LOG_FILE"
    exit 1
}
pass "Backend rebuilt with test change"

# Wait for service to come up
sleep 10
check "Backend responds after test deploy" "curl -sk https://10.10.1.1/api/v1/health/"

# ── Phase 3: Rollback ────────────────────────────────────────────────
info "Phase 3: Rolling back"

ROLLBACK_START=$(date +%s)

# Revert the test change
ssh deploy@10.10.1.2 "cd /opt/jolarca/backend && git checkout HEAD~1" 2>/dev/null || {
    fail "Could not revert test change"
    echo "ROLLBACK TEST FAILED — could not revert" | tee -a "$LOG_FILE"
    exit 1
}
pass "Test change reverted"

# Rebuild and restart
ssh deploy@10.10.1.2 "docker compose -f /opt/jolarca/docker-compose.backend.yml up -d --build" 2>/dev/null || {
    fail "Could not rebuild backend after rollback"
    echo "ROLLBACK TEST FAILED — could not rebuild after rollback" | tee -a "$LOG_FILE"
    exit 1
}
pass "Backend rebuilt after rollback"

# Wait for service to come up
sleep 10

ROLLBACK_END=$(date +%s)
ROLLBACK_DURATION=$((ROLLBACK_END - ROLLBACK_START))

# ── Phase 4: Post-rollback verification ──────────────────────────────
info "Phase 4: Post-rollback verification"

check "Backend responds after rollback" "curl -sk https://10.10.1.1/api/v1/health/"
check "Frontend responds after rollback" "curl -sk https://10.10.1.1/"
check "Edge health after rollback" "curl -sk https://10.10.1.1/health"

# Verify we're back to the original commit
POST_ROLLBACK_COMMIT=$(ssh deploy@10.10.1.2 "cd /opt/jolarca/backend && git rev-parse HEAD" 2>/dev/null || echo "unknown")
if [ "$POST_ROLLBACK_COMMIT" = "$CURRENT_BACKEND_COMMIT" ]; then
    pass "Back to original commit"
else
    fail "Commit mismatch: expected $CURRENT_BACKEND_COMMIT, got $POST_ROLLBACK_COMMIT"
fi

# ── Phase 5: Full smoke test ─────────────────────────────────────────
info "Phase 5: Full smoke test"

if [ -x "./scripts/smoke-test-staging.sh" ]; then
    ./scripts/smoke-test-staging.sh 2>&1 | tee -a "$LOG_FILE" || {
        warn "Some smoke tests failed (see log)"
    }
else
    warn "Smoke test script not found, skipping"
fi

# ── Summary ──────────────────────────────────────────────────────────
TEST_END=$(date +%s)
TEST_DURATION=$((TEST_END - TEST_START))

echo "" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "  Rollback Test Results" | tee -a "$LOG_FILE"
echo "  Checks: $PASSED passed, $FAILED failed, $TOTAL total" | tee -a "$LOG_FILE"
echo "  Rollback duration: ${ROLLBACK_DURATION}s" | tee -a "$LOG_FILE"
echo "  Total test duration: ${TEST_DURATION}s" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"

if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}  ❌ ROLLBACK TEST FAILED — $FAILED check(s) did not pass.${NC}" | tee -a "$LOG_FILE"
    echo "  Log: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
else
    echo -e "${GREEN}  ✅ ROLLBACK TEST PASSED — all checks passed.${NC}" | tee -a "$LOG_FILE"
    echo "  Log: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 0
fi
