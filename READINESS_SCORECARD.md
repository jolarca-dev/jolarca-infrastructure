# READINESS SCORECARD — jolarca-marketplace

**Date:** 2026-09-02  
**Assessor:** Principal Solutions Architect & CCO (independent verification)  
**Product:** jolarca-marketplace — all-Europe B2B/B2C ecclesiastical/end-of-life marketplace  
**Pilot market:** Lithuania (LT)  
**Target:** Proxmox bare-metal deployment (~3 days)  
**Compliance frame:** SOC 2 / ISO 27001:2022 / GDPR / PCI-DSS SAQ-A

> **Rule:** Evidence or it didn't happen. Every claim verified by command + output.

---

## Verdict: ❌ NO-GO for production · ✅ CONDITIONAL-GO for staging

The system **cannot** be deployed to production in 3 days. The deployment infrastructure (Proxmox hardening, Ansible roles, WireGuard, Vault, nginx edge, backups) does not exist as executable code — it exists as reserved structure and documentation.

**The correct action:** Deploy to a **staging environment** on Proxmox when it arrives. Production cutover is a separate gated step after all Critical blockers are resolved.

---

## Scorecard Summary

| # | Capability | Verdict | Critical? |
|---|-----------|---------|-----------|
| R1 | Tests | **PROVEN** | ✅ Yes |
| R2 | Audits / Security Scans | **PARTIAL** | ✅ Yes |
| R3 | Payments Boundary | **PROVEN** | ✅ Yes |
| R4 | Database | **PARTIAL** | ✅ Yes |
| R5 | GDPR | **PARTIAL** | ✅ Yes |
| R6 | Deployment Path | **ABSENT** | ✅ Yes |
| R7 | i.SAF / VAT | **PARTIAL** | ⚠️ High |

**Score: 1 PROVEN (Critical), 4 PARTIAL, 1 ABSENT, 1 PARTIAL (High)**

---

## R1: Tests — ✅ PROVEN

### Evidence

```
jolarca app:
  - 56 test files (unit + security + contract + integration)
  - Coverage gate: 80% enforced in CI (--cov-fail-under=80)
  - CI job name: "ci" (matches branch protection status check)
  - Test targets: make test (fast), make test-integration (full stack)
  - Settings: DJANGO_SETTINGS_MODULE=project.settings.test

jolarca-infrastructure:
  - terraform validate in CI (fmt + validate)
  - 3 OPA/Rego policies (no-public-ips, require-cmek, no-basic-iam-roles)
  - Ansible Molecule: RESERVED (no roles populated)

jolarca-compliance:
  - retention/tests/test_retention.py: 15 proofs (unittest)
  - retention-ci.yml: daily CI gate

jolarca-legal: make check (front-matter + register + governance)
jolarca-data: make check (seed schema + catalog lint + PII tripwire)
```

### Finding

Application test suite is **production-grade** with coverage enforcement. Infrastructure tests are limited to Terraform validation. Ansible Molecule tests are scaffolded but empty.

---

## R2: Audits / Security Scans — ⚠️ PARTIAL

### Evidence

```
gitleaks (secret scanning):
  ✅ jolarca: security.yml + pre-commit
  ✅ jolarca-infrastructure: security-scan.yml
  ✅ jolarca-compliance: pre-commit
  ✅ jolarca-legal: pre-commit
  ✅ jolarca-data: pre-commit

Trivy (dependency vulnerability):
  ✅ jolarca: security.yml
  ✅ jolarca-infrastructure: security-scan.yml
  ❌ jolarca-compliance: NOT FOUND
  ❌ jolarca-legal: NOT FOUND
  ❌ jolarca-data: NOT FOUND

CodeQL (SAST):
  ❌ jolarca: NOT FOUND
  ⚠️ jolarca-infrastructure: DISABLED (codeql.yml.disabled)
  ⚠️ jolarca-compliance: DISABLED
  ⚠️ jolarca-legal: DISABLED
  ⚠️ jolarca-data: DISABLED

Dependabot:
  ✅ All 5 repos: CONFIGURED

Secrets in repo:
  ✅ CLEAN — no hardcoded passwords/secrets/API keys found
```

### Finding

Secret scanning is universal. Dependency scanning is only in 2/5 repos. **CodeQL is disabled everywhere** — no static analysis running. Dependabot provides advisory alerts but doesn't block merges.

**Gap:** No SAST tool is actively scanning code. This is a SOC 2 CC7.1 gap.

---

## R3: Payments Boundary — ✅ PROVEN

### Evidence

```
Stripe import isolation:
  ✅ ONLY payments_app imports stripe (3 files: __init__.py, webhooks.py, services.py)
  ✅ __init__.py enforces: "no other app may `import stripe`"
  ✅ Boundary guard script: scripts/check-payment-boundary.sh (ADR-0005)

Webhook signature verification:
  ✅ stripe.Webhook.construct_event() is the ONLY parser
  ✅ _verify_and_parse() rejects invalid signatures → 400
  ✅ Audit log: "stripe_webhook_rejected" on signature failure

Idempotency:
  ✅ Idempotency-Key in CORS allowed headers
  ✅ test_idempotency_conflict_409
  ✅ test_missing_idempotency_key_400
  ✅ Fingerprint-based dedup (test_idempotency.py)

PAN handling:
  ✅ No card_number/PAN/primary_account in codebase
  ✅ SAQ-A posture: Stripe Elements (js.stripe.com) is client-side only
  ✅ Boundary guard explicitly exempts js.stripe.com (browser-only)

Test-mode:
  ✅ STRIPE_SECRET_KEY from environment (never in repo)
  ✅ stripe-mock in dev-up (docker compose)
```

### Finding

Payment boundary is **architecturally sound and proven by tests**. The fence test, boundary guard script, and webhook verification form a defense-in-depth pattern. SAQ-A self-attestation is supportable.

---

## R4: Database — ⚠️ PARTIAL

### Evidence

```
Migrations:
  ✅ 23 Django migration files exist
  ✅ Migration consistency checked by `make check`

Encryption at rest:
  ✅ pgcrypto extension: CREATE EXTENSION IF NOT EXISTS pgcrypto (init-extensions.sql)
  ✅ EncryptedTextField: apps/core/encryption.py (transparent encrypt-on-write/decrypt-on-read)
  ✅ GDPR Art. 32 alignment documented

Backups:
  ❌ BorgBackup: RESERVED (offsite-repo.md is a specification, not implementation)
  ❌ ansible/playbooks/50-backup.yml: DOES NOT EXIST
  ❌ No backup job configured

Restore drill:
  ⚠️ restore-drill.md: DOCUMENTED (RTO ≤ 4h, RPO ≤ 15min)
  ❌ No evidence of drill execution (no timestamps, no results)
  ❌ Quarterly cadence not started
```

### Finding

Database schema and encryption are production-ready. **Backups are not implemented.** The restore drill is documented but never executed. This is a **Critical blocker** — SOC 2 A1.3 and ISO 27001 A.5.29 require tested backups.

---

## R5: GDPR — ⚠️ PARTIAL

### Evidence

```
Consent enforcement:
  ✅ GDPR_CONSENT_REQUIRED = True (settings/base.py)
  ✅ ConsentRecord model: immutable ledger (Art. 7)
  ✅ ConsentPurpose choices defined
  ✅ SESSION_COOKIE_AGE = 14 days with re-consent flow

Erasure/export:
  ✅ compliance_app: erasure fan-out, portability exports
  ✅ test_erasure_registry.py: asserts all PII stores have erasure handlers
  ✅ test_nightly_sweep_only_touches_completed_erasures
  ✅ Celery beat: compliance-erasure-sla (SLA-tracked)

DPIA:
  ⚠️ DPIA template: EXISTS
  ⚠️ DPIA-003 (Payments and VAT): DRAFT SKELETON — NOT SIGNED
  ❌ G3 decision: "DPIA 003 signed + hash (currently draft skeleton)" — WITHHELD

Retention:
  ✅ retention/matrix.yaml: LT 10Y (RC-ACCT-10Y), LT 50Y (RC-PAYROLL-50Y)
  ✅ Retention engine: executable code with 15 proofs
  ✅ Hold guard, adversarial anonymization, report-only for counsel-pending
  ✅ retention-ci.yml: daily CI gate
```

### Finding

Consent and erasure are **architecturally sound**. Retention-as-code is exemplary. **DPIA-003 is unsigned** — this is a G3 gate withholding item and a **Critical blocker** for production. The DPO must sign before any real payment processing.

---

## R6: Deployment Path — ❌ ABSENT

### Evidence

```
Proxmox:
  ❌ No Proxmox configuration exists
  ❌ No VM/LXC layout defined
  ❌ No Packer/templates for VM images

Ansible roles:
  ❌ ansible/roles/ contains ONLY .gitkeep files (0 playbooks)
  ⚠️ Planned sequence: 00-hardening → 10-wireguard → 20-postgresql → 30-vault →
     40-minio → 50-backup → 60-nginx-edge → 70-monitoring → 90-disaster-recovery
  ❌ NONE of these playbooks exist

WireGuard:
  ⚠️ Documented in architecture.md and threat-model.md
  ❌ 10-wireguard.yml: DOES NOT EXIST
  ⚠️ Key rotation runbook: "skeleton — lands with the ansible 10-wireguard.yml workstream"

Vault:
  ⚠️ ansible-vault password custody documented (dual control)
  ❌ HashiCorp Vault bootstrap: DOES NOT EXIST
  ❌ 30-vault.yml: DOES NOT EXIST

TLS / Reverse proxy:
  ❌ 60-nginx-edge: "pending" (per audit report F-12)
  ❌ No TLS configuration exists

Rollback:
  ⚠️ CONTRIBUTING.md: "risk class, blast radius, and rollback plan" required
  ❌ No tested rollback procedure exists
```

### Finding

**The deployment infrastructure does not exist as executable code.** Everything is reserved structure, documentation, or scaffolded directories. This is the **single largest blocker**. The Proxmox server arriving in 3 days has no provisioning plan to deploy onto it.

---

## R7: i.SAF / VAT — ⚠️ PARTIAL

### Evidence

```
i.SAF FR0600:
  ✅ Obligation registered: regulatory/tax-authorities/vmi-lt/2026-08-17-obligation-isaf-fr0600.md
  ✅ Compliance repo references OBL-001

VIES validation:
  ⚠️ FORMAT-ONLY: "vies_checked": false — honest contract
  ❌ Live VIES gateway: UNWIRED (MVP-T3)
  ⚠️ Test: test_invalid_vat_id_is_400_and_valid_passes (format check only)
  ❌ G3 decision: "VIES VAT reconciliation evidence" — WITHHELD

VAT OSS:
  ⚠️ Documented in jolarca-legal (corporate/registrations/oss/)
  ⚠️ Clause library: "Prices exclusive of VAT; invoice must show VAT ID"
  ❌ OSS registration: NOT COMPLETED (directory exists, no filing evidence)
```

### Finding

i.SAF obligation is registered. **VIES is not wired to the live EU gateway** — format validation only. OSS registration is not completed. For Lithuania pilot with B2C sales, VIES is needed for B2B VAT validation. OSS is needed for cross-border B2C VAT reporting.

---

## Gap Summary

| Gap | Severity | Blocks Production? | Blocks Staging? |
|-----|----------|--------------------|-----------------|
| Ansible roles empty (no provisioning) | Critical | ✅ YES | ✅ YES |
| Backups not implemented | Critical | ✅ YES | No |
| Restore drill never executed | Critical | ✅ YES | No |
| DPIA-003 unsigned | Critical | ✅ YES | No |
| VIES not wired (format-only) | High | ✅ YES (B2B) | No |
| CodeQL/SAST disabled | High | No (risk-accept) | No |
| Trivy missing in 3 repos | Medium | No (risk-accept) | No |
| OSS registration incomplete | Medium | ✅ YES (B2C EU) | No |
| No TLS/nginx edge | Critical | ✅ YES | ✅ YES |
| No Vault bootstrap | Critical | ✅ YES | Partial |
| No WireGuard playbook | Critical | ✅ YES | ✅ YES |
| No monitoring/alerting | High | No (risk-accept) | No |

---

## Earliest Honest Production Date

Given the Critical gaps (especially Ansible roles, backups, WireGuard, nginx edge, Vault), the earliest honest production deployment is **4–6 weeks**, not 3 days.

**3-day milestone should be:** Proxmox arrives → harden host → deploy **staging** environment → begin Ansible role development against real hardware.
