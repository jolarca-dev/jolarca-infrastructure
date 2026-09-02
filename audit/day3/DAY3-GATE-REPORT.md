# DAY 3 GATE REPORT

**Date:** [YYYY-MM-DD]
**Operator:** [name]
**Application SHA:** [commit SHA deployed]
**Environment:** staging

---

## Premise Check

| Check | Result | Evidence |
|-------|--------|----------|
| Day 2 commits present | [ ] | `git log --oneline -5` |
| audit/day2/ evidence present | [ ] | `ls audit/day2/` |
| 7 VMs reachable over WireGuard | [ ] | `wg show` + ping matrix |
| Vault unsealed + healthy | [ ] | `vault status` |
| Vault ACL denial re-confirmed | [ ] | `vault read` with wrong policy |
| No sk_live in any repo | [ ] | `git grep -rn 'sk_live'` |
| Application tests green | [ ] | `pytest` output |

**Premise verdict:** [ ] PASS / [ ] FAIL

---

## Phase Evidence

### D3-A: Data Plane

| Check | Result | Evidence |
|-------|--------|----------|
| PG 15 + extensions | [ ] | `psql \dx` output |
| PG listen on WG IP only | [ ] | `ss -tlnp \| grep 5432` |
| PG TLS from internal CA | [ ] | `openssl s_client` output |
| PG negative: edge→db denied | [ ] | `nc -zv` output |
| PG negative: readonly DROP denied | [ ] | `psql` error output |
| Redis bound to WG IP | [ ] | `ss -tlnp \| grep 6379` |
| Redis requirepass from Vault | [ ] | `redis.conf` excerpt |
| Redis negative: no-auth → NOAUTH | [ ] | `redis-cli ping` output |
| Redis negative: edge→redis denied | [ ] | `nc -zv` output |
| MinIO TLS from internal CA | [ ] | `openssl s_client` output |
| MinIO service account least-priv | [ ] | `mc admin policy` output |
| MinIO negative: anon denied | [ ] | `curl` output |

**Data plane verdict:** [ ] PASS / [ ] CONDITIONAL

### D3-B: Application Plane

| Check | Result | Evidence |
|-------|--------|----------|
| Deployed at pinned SHA | [ ] | `git rev-parse HEAD` |
| Migrations clean | [ ] | `manage.py migrate` output |
| DEBUG=False | [ ] | `settings.py` grep |
| ALLOWED_HOSTS staging only | [ ] | `settings.py` grep |
| STRIPE_MODE=test | [ ] | `settings.py` grep |
| No plaintext secrets on disk | [ ] | `grep -r` scan output |
| No secrets in process env | [ ] | `/proc/<pid>/environ` perms |
| Health endpoint green | [ ] | `curl` output |
| Celery worker active | [ ] | `systemctl status` output |

**App plane verdict:** [ ] PASS / [ ] CONDITIONAL

### D3-C: Edge + TLS

| Check | Result | Evidence |
|-------|--------|----------|
| Internal CA TLS (not snakeoil) | [ ] | `openssl s_client -issuer` |
| TLS 1.2+ only | [ ] | `openssl s_client -tls1_1` fails |
| HSTS present | [ ] | `curl -I` output |
| Security headers present | [ ] | `curl -I` output |
| IP allowlist / basic-auth gate | [ ] | `curl` without auth → 401/403 |
| WAF log-mode verified | [ ] | Test attack string logged |
| Rate limiting configured | [ ] | `nginx.conf` excerpt |
| Negative: non-allowlisted → 403 | [ ] | `curl` output |
| Negative: TLS fails without CA | [ ] | `curl -k` vs `curl --cacert` |
| Negative: direct app:8000 refused | [ ] | `curl` from operator machine |
| Negative: wrong basic-auth → 401 | [ ] | `curl` output |

**Edge verdict:** [ ] PASS / [ ] CONDITIONAL

### D3-D: Backup + Monitoring

| Check | Result | Evidence |
|-------|--------|----------|
| Borg repo initialized | [ ] | `borg info` output |
| First backup taken | [ ] | `borg list` output |
| Restore drill passed | [ ] | Scratch DB query output |
| Offsite config present | [ ] | Config file or dated TODO |
| 7/7 node_exporter targets UP | [ ] | Prometheus targets API |
| Grafana admin from Vault | [ ] | `grafana.ini` excerpt |
| Test alert fired + received | [ ] | Alertmanager/screenshot |
| Logs flowing to Loki | [ ] | Known request in Loki |

**Backup+monitoring verdict:** [ ] PASS / [ ] CONDITIONAL

---

## Smoke Suite Results

| # | Assertion | Result |
|---|-----------|--------|
| 1 | Edge health through auth gate | [ ] |
| 2 | Login flow with seeded test user | [ ] |
| 3 | Read path touching PG | [ ] |
| 4 | Write path persists | [ ] |
| 5 | Media upload via MinIO | [ ] |
| 6 | Celery task completes | [ ] |
| 7 | Stripe test-mode checkout | [ ] |
| 8 | VIES badge / frontend check | [ ] |
| 9 | 7/7 monitoring targets UP | [ ] |
| 10 | Backup exists, <26h old | [ ] |

**Smoke verdict:** [X]/10 passed

---

## Open Issues

| # | Severity | Description | Owner | ETA |
|---|----------|-------------|-------|-----|
| | | | | |

---

## Verdict

**Staging is [UP / CONDITIONAL].**

- Smoke suite: [X]/10 passed
- Plaintext secret scan: [CLEAN / DEFECT]
- Negative tests: [ALL PASS / X FAILED]

**Staging is up. No pilot traffic. Production cutover remains gated on
P4–P7 execution on this hardware (backup drill started, TLS public
issuance, DPIA-003 DPO signature, OSS registration with VMI — 4–8
week lead, monitoring soak).**

---

**Operator signature:** _______________________________
**Date:** _______________
