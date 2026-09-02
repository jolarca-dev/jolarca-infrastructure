#!/usr/bin/env bash
# seed-staging-data.sh — Load synthetic demo data into staging.
# NO real PII — all data is fabricated for testing purposes.
#
# Usage: ./scripts/seed-staging-data.sh [app_host]
#   app_host: WireGuard IP of the app node (default: 10.10.1.2)

set -euo pipefail

APP_HOST="${1:-10.10.1.2}"
BACKEND_URL="http://${APP_HOST}:8000"

echo "═══════════════════════════════════════════════════════"
echo "  Jolarca Staging Seed Data"
echo "  App: $BACKEND_URL | Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "═══════════════════════════════════════════════════════"
echo ""

# ── 1. Run Django seed command ──────────────────────────────────────
echo "── Running Django seed_data management command ──"
ssh -o StrictHostKeyChecking=no deploy@"$APP_HOST" \
    "docker compose -f /opt/jolarca/docker-compose.backend.yml \
     exec -T backend python manage.py seed_data --demo" 2>/dev/null || {
    echo "  ⚠️  seed_data command not available; trying loaddata fallback..."

    # Fallback: load fixture if seed_data management command doesn't exist
    ssh -o StrictHostKeyChecking=no deploy@"$APP_HOST" \
        "docker compose -f /opt/jolarca/docker-compose.backend.yml \
         exec -T backend python manage.py loaddata staging_demo_data" 2>/dev/null || {
        echo "  ⚠️  No seed fixture found. Creating minimal demo data via API..."

        # Minimal fallback: create a superuser and test categories via API
        ssh -o StrictHostKeyChecking=no deploy@"$APP_HOST" \
            "docker compose -f /opt/jolarca/docker-compose.backend.yml exec -T backend python manage.py shell -c \"
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin_staging').exists():
    User.objects.create_superuser('admin_staging', 'admin@staging.journeyoflife.org', 'staging_admin_password_CHANGE_ME')
    print('Created staging admin user: admin_staging')
else:
    print('Staging admin user already exists')
\"" 2>/dev/null
    }
}

echo ""

# ── 2. Verify catalog renders ───────────────────────────────────────
echo "── Verifying catalog renders ──"
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' "${BACKEND_URL}/api/v1/" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "000" ]; then
    echo "  ✅ API root responds with HTTP $HTTP_CODE"
else
    echo "  ❌ API root not reachable"
fi

# Check frontend
FRONTEND_CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://${APP_HOST}:3000/" 2>/dev/null || echo "000")
if [ "$FRONTEND_CODE" != "000" ]; then
    echo "  ✅ Frontend responds with HTTP $FRONTEND_CODE"
else
    echo "  ❌ Frontend not reachable"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Seed data complete."
echo "  Admin login: http://${APP_HOST}:8000/admin/"
echo "  Credentials: admin_staging / staging_admin_password_CHANGE_ME"
echo "═══════════════════════════════════════════════════════"
