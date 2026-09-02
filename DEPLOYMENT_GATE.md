# DEPLOYMENT GATE — jolarca-marketplace

**Date:** 2026-09-02  
**Gate type:** Binary go/no-go (evidence-backed)  
**Target:** Proxmox production deployment  
**Rule:** A single failed Critical item = NO-GO, regardless of the calendar.

---

## Verdict: ❌ NO-GO for production · ✅ CONDITIONAL-GO for staging

---

## Critical Items (all must pass for production)

| # | Requirement | Status | Evidence |
|---|------------|--------|----------|
| C1 | Tests green + coverage gate enforced | ✅ PASS | `pytest --cov-fail-under=80` in CI; 56 test files |
| C2 | No open critical vulnerabilities | ⚠️ UNVERIFIED | Dependabot active but no scan results reviewed; CodeQL disabled |
| C3 | Payments boundary proven (SAQ-A, webhook idempotency) | ✅ PASS | Stripe isolated to payments_app; construct_event verified; idempotency tested |
| C4 | PII encrypted at rest (proven) | ⚠️ PARTIAL | pgcrypto + EncryptedTextField exist; **not verified against live DB** |
| C5 | GDPR erasure/consent working | ⚠️ PARTIAL | Code exists + tests pass; **DPIA-003 unsigned** |
| C6 | Backups tested (restore drill) | ❌ FAIL | Backups not implemented; restore drill never executed |
| C7 | Secrets in Vault (none in repo) | ✅ PASS | gitleaks clean; no hardcoded secrets found |
| C8 | Rollback plan documented | ⚠️ PARTIAL | CONTRIBUTING.md requires it; **no tested procedure** |

**Critical score: 3 PASS, 4 PARTIAL/FAIL, 0 FULLY PASS on infra items**

---

## High Items (block unless risk-accepted by owner)

| # | Requirement | Status | Evidence |
|---|------------|--------|----------|
| H1 | DPIA signed (DPO) | ❌ FAIL | DPIA-003 is draft skeleton; G3 gate WITHHELD |
| H2 | i.SAF filing mechanism ready | ⚠️ PARTIAL | Obligation registered; no filing mechanism implemented |
| H3 | VIES validation live | ❌ FAIL | Format-only; `vies_checked: false`; live gateway unwired |
| H4 | Monitoring/alerting armed | ❌ FAIL | monitoring/ contains only .gitkeep files |
| H5 | Incident runbook exists | ⚠️ PARTIAL | Policy exists (06-incident-response.md); no executable runbook |

**High score: 0 PASS, 3 PARTIAL, 2 FAIL**

---

## Gate Decision Matrix

```
                    Production    Staging
                    ──────────    ───────
Critical items:     ❌ NO-GO      ✅ CONDITIONAL
High items:         ❌ NO-GO      ⚠️ Risk-accept OK
Calendar (3 days):  ❌ NO-GO      ✅ GO (staging only)
```

---

## Production Gate — Detailed Findings

### C1: Tests green + coverage gate — ✅ PASS

```
Command: pytest tests/unit tests/security --cov=. --cov-fail-under=80
CI: .github/workflows/ci.yml (jolarca)
Result: Coverage gate enforced; 56 test files; CI status check required by branch protection
```

### C2: No open critical vulnerabilities — ⚠️ UNVERIFIED

```
Dependabot: CONFIGURED in all 5 repos
Trivy: Only in jolarca + jolarca-infrastructure (3/5 repos missing)
CodeQL: DISABLED everywhere (codeql.yml.disabled)
Result: Cannot verify — no active SAST or comprehensive dependency scan
```

**To pass:** Enable CodeQL or Semgrep; run Trivy in all repos; review Dependabot alerts.

### C3: Payments boundary proven — ✅ PASS

```
Stripe import: ONLY payments_app (3 files)
Webhook: stripe.Webhook.construct_event() verified
Idempotency: Fingerprint dedup + CORS + tests
PAN: Not present in codebase
Boundary guard: scripts/check-payment-boundary.sh (ADR-0005)
```

### C4: PII encrypted at rest — ⚠️ PARTIAL

```
pgcrypto: CREATE EXTENSION in init-extensions.sql
EncryptedTextField: apps/core/encryption.py
Result: Code exists but NOT verified against live database
```

**To pass:** Deploy to staging; INSERT test PII; SELECT raw bytes to verify ciphertext.

### C5: GDPR erasure/consent — ⚠️ PARTIAL

```
Consent: ConsentRecord model (immutable ledger); GDPR_CONSENT_REQUIRED=True
Erasure: compliance_app fan-out; test_erasure_registry.py
DPIA-003: DRAFT — NOT SIGNED (G3 gate WITHHELD)
```

**To pass:** DPO signs DPIA-003; hash committed to compliance repo.

### C6: Backups tested — ❌ FAIL

```
BorgBackup: Specification only (offsite-repo.md)
Ansible 50-backup.yml: DOES NOT EXIST
Restore drill: Documented (restore-drill.md) but NEVER EXECUTED
```

**To pass:** Implement backup playbook; execute restore drill; record results with timestamp.

### C7: Secrets in Vault — ✅ PASS

```
gitleaks: Configured in all repos (pre-commit + CI)
Manual scan: No hardcoded passwords/secrets/API keys found
SOPS: Configured for compliance + legal repos (.sops.yaml)
```

### C8: Rollback plan — ⚠️ PARTIAL

```
CONTRIBUTING.md: Requires rollback plan for production changes
Actual procedure: NONE TESTED
```

**To pass:** Document rollback procedure per service; test in staging.

---

## Staging Gate — Findings

For staging deployment, the gate is less strict:

| Item | Required for Staging? | Status |
|------|----------------------|--------|
| Tests green | ✅ Yes | ✅ PASS |
| Payments boundary (test mode) | ✅ Yes | ✅ PASS |
| Secrets not in repo | ✅ Yes | ✅ PASS |
| PII encryption code | ✅ Yes | ✅ PASS (code exists) |
| Backups | ⚠️ Recommended | ❌ Not implemented |
| DPIA signed | ❌ Not required (no real data) | ⚠️ Draft |
| VIES live | ❌ Not required (test mode) | ❌ Not wired |
| Monitoring | ⚠️ Recommended | ❌ Not implemented |
| Proxmox provisioning | ✅ Yes | ❌ Not implemented |
| WireGuard | ✅ Yes | ❌ Not implemented |
| TLS/nginx | ✅ Yes | ❌ Not implemented |

**Staging verdict:** CONDITIONAL-GO — the application code is ready, but the infrastructure provisioning (Ansible roles, WireGuard, nginx) must be built first.

---

## Correct Action for 3-Day Proxmox Arrival

```
Day 1: Proxmox arrives
  → Install Proxmox on bare metal
  → Harden host (CIS baseline)
  → Configure network (VLANs, firewall)

Day 2: Infrastructure bootstrap
  → Create VMs/LXCs per PROXMOX_DEPLOYMENT_PLAN.md
  → Bootstrap Vault (unseal keys, PKI)
  → Configure WireGuard mesh
  → Set up nginx edge (TLS via Let's Encrypt staging)

Day 3: Staging deployment
  → Deploy PostgreSQL + PostGIS
  → Deploy application (Django + Next.js) in TEST mode
  → Deploy MinIO (object storage)
  → Configure monitoring (Prometheus + Grafana)
  → Run smoke tests
  → NO pilot traffic
```

**Production cutover is a SEPARATE gated step** after:
1. All Critical items pass
2. DPIA-003 signed by DPO
3. VIES wired to live gateway
4. Backup + restore drill completed
5. Monitoring armed and alerting tested
