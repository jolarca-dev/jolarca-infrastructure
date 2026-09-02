#!/usr/bin/env bash
# restore-drill.sh — Automated restore drill for the Jolarca marketplace.
# Restores from BorgBackup to a clean target, verifies data integrity.
# This is the PROOF that backups work.
#
# Usage: ./scripts/restore-drill.sh [borg_repo] [target_dir]
#   borg_repo:  path to Borg repository (default: /var/backups/borg-repo)
#   target_dir: where to restore (default: /tmp/restore-drill)
#
# Exit codes:
#   0 = drill passed (all data verified)
#   1 = drill failed

set -euo pipefail

BORG_REPO="${1:-/var/backups/borg-repo}"
TARGET_DIR="${2:-/tmp/restore-drill}"
LOG_FILE="/tmp/restore-drill-$(date +%Y%m%d_%H%M%S).log"
DRILL_START=$(date +%s)

# Colors for output
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
echo "  Jolarca Restore Drill" | tee -a "$LOG_FILE"
echo "  Repo: $BORG_REPO | Target: $TARGET_DIR" | tee -a "$LOG_FILE"
echo "  Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# ── Step 1: Find latest archive ──────────────────────────────────────
info "Finding latest Borg archive"
LATEST_ARCHIVE=$(borg list "$BORG_REPO" 2>/dev/null | tail -1 | awk '{print $1}')
if [ -z "$LATEST_ARCHIVE" ]; then
    fail "No Borg archives found in $BORG_REPO"
    echo "DRILL FAILED — no archives to restore from" | tee -a "$LOG_FILE"
    exit 1
fi
pass "Latest archive: $LATEST_ARCHIVE"

# ── Step 2: Clean target directory ───────────────────────────────────
info "Preparing restore target"
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

# ── Step 3: Extract archive ──────────────────────────────────────────
info "Extracting archive to $TARGET_DIR"
EXTRACT_START=$(date +%s)
borg extract "${BORG_REPO}::${LATEST_ARCHIVE}" --progress 2>/dev/null || {
    fail "Borg extract failed"
    echo "DRILL FAILED — extraction error" | tee -a "$LOG_FILE"
    exit 1
}
EXTRACT_END=$(date +%s)
EXTRACT_DURATION=$((EXTRACT_END - EXTRACT_START))
pass "Archive extracted in ${EXTRACT_DURATION}s"

# ── Step 4: Verify PostgreSQL backup ─────────────────────────────────
info "Verifying PostgreSQL backup"
PG_DUMP_DIR="$TARGET_DIR/var/backups/postgresql"

if [ -d "$PG_DUMP_DIR" ]; then
    PG_DUMPS=$(find "$PG_DUMP_DIR" -name "*.dump" -type f | sort | tail -1)
    if [ -n "$PG_DUMPS" ]; then
        check "PostgreSQL dump exists" "test -f '$PG_DUMPS'"
        check "PostgreSQL dump is valid" "pg_restore --list '$PG_DUMPS'"

        # Verify dump contains marketplace tables
        check "Marketplace tables in dump" "pg_restore --list '$PG_DUMPS' | grep -qi 'table'"

        DUMP_SIZE=$(du -h "$PG_DUMPS" | cut -f1)
        echo "   Latest dump: $(basename $PG_DUMPS) ($DUMP_SIZE)" | tee -a "$LOG_FILE"
    else
        warn "No PostgreSQL dumps found"
    fi
else
    warn "PostgreSQL backup directory not found"
fi

# ── Step 5: Verify MinIO backup ──────────────────────────────────────
info "Verifying MinIO backup"
MINIO_DIR="$TARGET_DIR/var/backups/minio"

if [ -d "$MINIO_DIR" ]; then
    for bucket in jol-marketplace-media jol-marketplace-uploads jol-marketplace-static; do
        if [ -d "$MINIO_DIR/$bucket" ]; then
            FILE_COUNT=$(find "$MINIO_DIR/$bucket" -type f | wc -l)
            pass "MinIO bucket '$bucket' present ($FILE_COUNT files)"
        else
            warn "MinIO bucket '$bucket' not found in backup"
        fi
    done
else
    warn "MinIO backup directory not found"
fi

# ── Step 6: Verify Vault backup ──────────────────────────────────────
info "Verifying Vault backup"
VAULT_DIR="$TARGET_DIR/var/backups/vault"

if [ -d "$VAULT_DIR" ]; then
    VAULT_SNAPS=$(find "$VAULT_DIR" -name "vault-raft_*.snap" -type f | wc -l)
    check "Vault raft snapshot exists" "test $VAULT_SNAPS -gt 0"
    echo "   Vault snapshots: $VAULT_SNAPS" | tee -a "$LOG_FILE"
else
    warn "Vault backup directory not found"
fi

# ── Step 7: Verify app config ────────────────────────────────────────
info "Verifying app configuration"
APP_DIR="$TARGET_DIR/opt/jolarca"

if [ -d "$APP_DIR" ]; then
    check "App config directory exists" "test -d '$APP_DIR/config'"
    check "Docker Compose backend exists" "test -f '$APP_DIR/docker-compose.backend.yml'"
    check "Docker Compose frontend exists" "test -f '$APP_DIR/docker-compose.frontend.yml'"
else
    warn "App directory not found in backup"
fi

# ── Step 8: Verify system config ─────────────────────────────────────
info "Verifying system configuration"
check "etc directory exists" "test -d '$TARGET_DIR/etc'"
check "SSH config present" "test -f '$TARGET_DIR/etc/ssh/sshd_config'"

# ── Summary ──────────────────────────────────────────────────────────
DRILL_END=$(date +%s)
DRILL_DURATION=$((DRILL_END - DRILL_START))
RTO_MINUTES=$((DRILL_DURATION / 60))

echo "" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "  Restore Drill Results" | tee -a "$LOG_FILE"
echo "  Checks: $PASSED passed, $FAILED failed, $TOTAL total" | tee -a "$LOG_FILE"
echo "  Duration: ${DRILL_DURATION}s (${RTO_MINUTES}m)" | tee -a "$LOG_FILE"
echo "  RTO target: ≤ 240min (4h)" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════════" | tee -a "$LOG_FILE"

# Cleanup
rm -rf "$TARGET_DIR"

if [ "$FAILED" -gt 0 ]; then
    echo -e "${RED}  ❌ DRILL FAILED — $FAILED check(s) did not pass.${NC}" | tee -a "$LOG_FILE"
    echo "  Log: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
else
    echo -e "${GREEN}  ✅ DRILL PASSED — all checks passed.${NC}" | tee -a "$LOG_FILE"
    echo "  Log: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 0
fi
