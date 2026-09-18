# READINESS SCORECARD — jolarca-marketplace

**Date:** 2026-09-17 (supersedes the 2026-09-10 assessment)  
**Assessor:** Principal Solutions Architect & CCO (independent verification)  
**Product:** jolarca-marketplace — all-Europe B2B/B2C ecclesiastical/end-of-life marketplace  
**Pilot market:** Lithuania (LT)  
**Target:** Proxmox bare-metal deployment (~3 days)  
**Compliance frame:** SOC 2 / ISO 27001:2022 / GDPR / PCI-DSS SAQ-A

> **Rule:** Evidence or it didn't happen. Every claim verified by command + output.

---

## Verdict: ❌ NO-GO for production · ❌ NO-GO for staging

The system **cannot** be deployed in 3 days. Two independent blockers, not one:
the Proxmox hardware has not arrived, **and** five of ten Ansible roles currently
fail before reaching a host because they declare unresolvable defaults
(BLOCKERS.md B16). The 2026-09-10 revision of this document attributed the delay
to hardware alone; that claim did not survive verification — the roles were never
run because their Molecule suite has never executed in CI (B17).

> This document's own rule is "Evidence or it didn't happen." No role has a
> recorded successful run, so no role is scored as working.

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
| R6 | Deployment Path | **BROKEN (B16)** | ❌ No |
| R7 | i.SAF / VAT | **PARTIAL** | ⚠️ High |

**Score: 2 PROVEN (Critical), 1 BROKEN (Critical, was scored CODE READY), 3 PARTIAL, 1 PARTIAL (High)**

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
  - Ansible Molecule: 9 scenarios written and tracked (all roles except app),
    but CI has never executed one — ansible.yml runs molecule from the wrong
    directory, so every leg aborts at scenario discovery (BLOCKERS.md B17)

jolarca-compliance:
  - retention/tests/test_retention.py: 15 proofs (unittest)
  - retention-ci.yml: daily CI gate

jolarca-legal: make check (front-matter + register + governance)
jolarca-data: make check (seed schema + catalog lint + PII tripwire)
```

### Finding

Application test suite is **production-grade** with coverage enforcement. Infrastructure tests are limited to Terraform validation. Ansible Molecule scenarios exist but have never been executed by CI, so no role has ever been tested end to end — and the untested roles turn out to be broken (BLOCKERS.md B16).

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
  ✅ BorgBackup: Role implemented (255 lines); `80-backup.yml` playbook exists
  ✅ Covers: pg_dump, WAL archiving, MinIO mirror, Vault snapshot, Borg offsite
  ❌ No backup job RUNNING (needs hardware)

Restore drill:
  ✅ restore-drill.md: DOCUMENTED (RTO ≤ 4h, RPO ≤ 15min)
  ❌ No evidence of drill execution (no timestamps, no results)
  ❌ Quarterly cadence not started (needs hardware)
```

### Finding

Database schema and encryption are production-ready. **Backup code is implemented** (role + playbook). The restore drill is documented but never executed (requires hardware). This is a **Critical blocker** for production only — SOC 2 A1.3 and ISO 27001 A.5.29 require *tested* backups.

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

## R6: Deployment Path — ⛔ BROKEN (code present, fails before reaching a host)

### Evidence

```
Proxmox:
  ✅ PROXMOX_DEPLOYMENT_PLAN.md: Complete specification (VM/LXC layout, Day 1–3)
  ✅ terraform/modules/proxmox-vm + proxmox-lxc: Modules exist
  ❌ No physical host yet (hardware pending delivery)

Ansible roles (source present; "implemented" does not mean "runs" — see BLOCKERS.md B16):
  ✅ hardening (242 lines) → 00-hardening.yml
  ⛔ wireguard (54 lines) → 10-wireguard.yml — B16: 1 unresolvable default
  ⛔ vault (104 lines) → 30-vault.yml — B16: 6 unresolvable defaults
  ⛔ postgresql (109 lines) → 40-postgresql.yml — B16: 10 unresolvable defaults
  ✅ redis (47 lines) → 45-redis.yml
  ⛔ minio (74 lines) → 50-minio.yml — B16: 6 unresolvable defaults
  ✅ app (313 lines) → 65-app.yml — B16 + handler defects fixed
  ⛔ nginx (71 lines) → 70-nginx-edge.yml — B16: 5 unresolvable defaults
  ✅ backup (255 lines) → 80-backup.yml
  ✅ monitoring (194 lines) → 95-monitoring.yml
  ✅ nginx-hardening → 90-nginx-hardening.yml

WireGuard:
  ✅ 10-wireguard.yml + wireguard role: IMPLEMENTED
  ✅ Key generation, config template, systemd enable
  ⚠️ Key rotation runbook: skeleton (lands post-deployment)

Vault:
  ✅ 30-vault.yml + vault role: IMPLEMENTED (install, TLS, Raft, systemd)
  ✅ docs/secrets-flow.md: HV → AV architecture documented
  ✅ scripts/sync-hv-to-av.sh: Complete (140 lines)
  ❌ Not bootstrapped (needs hardware + unseal ceremony)

TLS / Reverse proxy:
  ✅ 70-nginx-edge.yml + 90-nginx-hardening.yml: IMPLEMENTED
  ✅ nginx role: config, security headers, rate limiting
  ❌ Not deployed (needs hardware)

Monitoring:
  ✅ 95-monitoring.yml + monitoring role (194 lines): IMPLEMENTED
  ✅ Prometheus + Grafana + Alertmanager configs in monitoring/
  ❌ Not deployed (needs hardware)

Rollback:
  ✅ scripts/rollback-test.sh: EXISTS
  ✅ jolarca/scripts/deploy.sh --rollback: IMPLEMENTED
  ❌ Never tested against live infrastructure
```

### Finding

**The deployment infrastructure exists as source, not as code known to run.** All 10
Ansible roles and 11 playbooks exist, but five of them (postgresql, minio, vault,
nginx, wireguard) abort during variable resolution, before contacting a host, because
they declare unresolvable defaults — see BLOCKERS.md B16. Physical hardware is not the
sole remaining gap: B16 and B17 must close first, otherwise Day 2 of the staging plan
fails at the first templated task.

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

## Gap Summary (Updated 2026-09-17)

| Gap | Severity | Blocks Production? | Blocks Staging? | Status |
|-----|----------|--------------------|-----------------|---------|
| B16: 5 roles declare unresolvable defaults | Critical | ✅ YES | ✅ YES | ❌ Open — found 2026-09-17 |
| B17: Molecule never executes in CI | Critical | ✅ YES | ✅ YES | ❌ Open — found 2026-09-17 |
| Proxmox hardware not delivered | Critical | ✅ YES | ✅ YES | ❌ Pending |
| ~~PostgreSQL version mismatch (16 vs 17)~~ | ~~Critical~~ | — | — | ✅ RESOLVED (app repo updated to PG 17) |
| ~~Deployment model unreconciled~~ | ~~High~~ | — | — | ✅ RESOLVED (ADR-0007 + app_deploy_mode, defects fixed) |
| Restore drill never executed | Critical | ✅ YES | No | ❌ Needs hardware |
| DPIA-003 unsigned | Critical | ✅ YES | No | ❌ Needs DPO |
| VIES not wired (format-only) | High | ✅ YES (B2B) | No | ❌ Needs dev |
| CodeQL/SAST disabled | High | No (risk-accept) | No | ❌ Needs enablement |
| OSS registration incomplete | Medium | ✅ YES (B2C EU) | No | ❌ Needs VMI |
| ~~Ansible roles empty~~ | ~~Critical~~ | — | — | ⚠️ Source written; 5/10 blocked by B16 |
| ~~Backups not implemented~~ | ~~Critical~~ | — | — | ⚠️ Code exists; unrunnable-by-dependency (B16 vault/postgresql) and never executed |
| ~~No TLS/nginx edge~~ | ~~Critical~~ | — | — | ⚠️ Code exists; nginx role blocked by B16 |
| ~~No Vault bootstrap~~ | ~~Critical~~ | — | — | ⚠️ Code exists; vault role blocked by B16 |
| ~~No WireGuard playbook~~ | ~~Critical~~ | — | — | ⚠️ Code exists; wireguard role blocked by B16 |
| ~~No monitoring/alerting~~ | ~~High~~ | — | — | ⚠️ Code exists; defaults resolve, but never executed |

---

## Earliest Honest Production Date

Given that the infrastructure code is written but five roles are known not to run
(B16), the timeline is:

- **B16 + B17 remediation (1 day, no hardware needed):** rewrite 28 defaults; fix the molecule working-directory; land one green `molecule test` per role
- **Staging (3 days from hardware arrival):** Proxmox install → VMs → run all playbooks → smoke tests
- **Production (3–4 weeks from hardware arrival):** Staging soak (7d) + restore drill + DPIA + VIES + CodeQL

The previous estimate of 4–6 weeks assumed 2–3 weeks of Ansible development. Most of
that authoring is done; what remains is proving it executes. The critical path is now:
**B16/B17 → hardware delivery → 3-day staging → 7-day soak → parallel compliance
workstreams → production cutover.**
