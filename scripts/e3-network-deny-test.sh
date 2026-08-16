#!/usr/bin/env bash
# e3-network-deny-test.sh — ADR-0005 guard (E3): credential-INDEPENDENT
# network denial proof.
#
# Proves the Model A topology control: a hub workload holding a VALID
# Stripe test key still CANNOT reach api.stripe.com, because the denial
# happens at the NETWORK layer (no egress route), before authentication
# is ever attempted. Controls proven:
#
#   NEGATIVE  hub-net workload  -> api.stripe.com : no route / DNS denied
#   POSITIVE  hub-net workload  -> payment-API stub: reachable (N2 row)
#   POSITIVE  boundary-net      -> api.stripe.com : reachable (sole
#                                   sanctioned Stripe egress)
#
# Staging topology (this script): docker networks stand in for the
# deployed planes — `--internal` network = hub plane (no external
# egress), standard network = boundary plane, payment-API stub is
# dual-homed (as the real boundary is). The k8s equivalent is the
# default-deny NetworkPolicy set (jol-hub infra) + the payments_app
# egress allow-list (marketplace GKE), per
# jol-m-infrastructure/security/network-policy.md.
#
# Usage: scripts/e3-network-deny-test.sh
set -euo pipefail

HUB_NET="e3-hub-net"
BOUNDARY_NET="e3-boundary-net"
API_CIDR="172.31.250.0/24"
HUB_IMG="python:3.12-slim"
# Syntactically valid Stripe TEST key shape. The network block happens
# below the auth layer, so the key's validity is irrelevant to the
# result — that IS the point of the credential-independent test.
VALID_TEST_KEY="sk_test_e3_credential_independent_proof_000000"

cleanup() {
  docker rm -f e3-hub-probe e3-boundary-probe e3-payment-api-stub >/dev/null 2>&1 || true
  docker network rm "$HUB_NET" "$BOUNDARY_NET" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

status=0

echo "== staging topology: hub plane (internal, no external egress) + boundary plane"
docker network create --internal --subnet "$API_CIDR" "$HUB_NET" >/dev/null
docker network create "$BOUNDARY_NET" >/dev/null

# Payment-API stub: dual-homed like the real boundary (hub-facing +
# external-facing). Serves a marker on 443/tcp.
docker run -d --name e3-payment-api-stub \
  --network "$HUB_NET" --ip 172.31.250.10 \
  "$HUB_IMG" python -m http.server 443 >/dev/null
docker network connect "$BOUNDARY_NET" e3-payment-api-stub >/dev/null
sleep 2

echo "== NEGATIVE: hub workload WITH a valid Stripe test key -> api.stripe.com"
if docker run --rm --network "$HUB_NET" "$HUB_IMG" python - "$VALID_TEST_KEY" <<'EOF'
import sys, socket
key = sys.argv[1]
try:
    socket.create_connection(("api.stripe.com", 443), timeout=8)
    print(f"CRITICAL: hub reached api.stripe.com with key {key[:12]}...")
    sys.exit(1)
except OSError as exc:
    print(f"BLOCKED BY NETWORK: {type(exc).__name__}: {exc}")
    sys.exit(0)
EOF
then echo "NEGATIVE PASS: hub egress denied at network layer"; else status=1; echo "NEGATIVE FAIL"; fi

echo "== POSITIVE: hub workload -> payment-API stub (the N2 sanctioned row)"
if docker run --rm --network "$HUB_NET" "$HUB_IMG" python - <<'EOF'
import sys, urllib.request
try:
    r = urllib.request.urlopen("http://172.31.250.10:443/", timeout=8)
    print(f"REACHABLE: payment API via sanctioned row (HTTP {r.status})")
    sys.exit(0)
except OSError as exc:
    print(f"UNREACHABLE: {type(exc).__name__}: {exc}")
    sys.exit(1)
EOF
then echo "POSITIVE PASS: sanctioned flow works"; else status=1; echo "POSITIVE FAIL (N2 row)"; fi

echo "== POSITIVE: boundary plane -> api.stripe.com (sole sanctioned egress)"
if docker run --rm --network "$BOUNDARY_NET" "$HUB_IMG" python - <<'EOF'
import sys, socket
try:
    socket.create_connection(("api.stripe.com", 443), timeout=8)
    print("REACHABLE: boundary plane reaches Stripe (sanctioned)")
    sys.exit(0)
except OSError as exc:
    print(f"UNREACHABLE: {type(exc).__name__}: {exc}")
    sys.exit(1)
EOF
then echo "POSITIVE PASS: boundary->Stripe works"; else status=1; echo "POSITIVE FAIL"; fi

[ "$status" -eq 0 ] && echo "E3 NETWORK DENY: ALL CHECKS PASSED"
exit "$status"
