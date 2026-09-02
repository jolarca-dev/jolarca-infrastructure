# Pre-Proxmox Audit Plan — Work While Waiting for Hardware

**Created:** 2026-09-02
**Purpose:** Identify all concrete work items that can be completed before
Proxmox hardware arrives. Every item is actionable without running VMs.
**Priority:** P0 = blocks production cutover, P1 = should be done before
hardware arrives, P2 = improves quality but doesn't block.

---

## Summary of Findings

| Repo | Critical Gaps | High Gaps | Medium Gaps |
|------|:---:|:---:|:---:|
| jolarca (main) | 1 | 2 | 3 |
| jolarca-infrastructure | 2 | 3 | 2 |
| jolarca-legal | 0 | 3 | 0 |
| jolarca-compliance | 0 | 3 | 1 |

---

## P0 — BLOCKS PRODUCTION CUTOVER

### 1. Add `zeep` to backend requirements (VIES client dependency)
- **Repo:** jolarca
- **File:** `backend/requirements/base.txt`
- **Why:** The VIES live validation client (`tax_app/vies_client.py`) imports `zeep` for SOAP calls. Without it in requirements, the import fails at runtime and VIES falls back to HTTP (less reliable).
- **Action:** Add `zeep>=4.2` to `backend/requirements/base.txt`
- **Estimate:** 5 minutes

### 2. Create production inventory
- **Repo:** jolarca-infrastructure
- **File:** `ansible/inventories/production/hosts.yml`
- **Why:** Day 3 deployment plan references `ansible/inventories/production/hosts.yml` but it doesn't exist. Cannot deploy to production without it.
- **Action:** Create production inventory mirroring staging structure with production IPs/hostnames (placeholder until hardware arrives)
- **Estimate:** 30 minutes

### 3. Create Redis playbook (45-redis.yml)
- **Repo:** jolarca-infrastructure
- **File:** `ansible/playbooks/45-redis.yml`
- **Why:** Redis role exists (created in Day 3 prep) but has no playbook to deploy it. Celery broker requires Redis.
- **Action:** Create `45-redis.yml` targeting the app host (Redis runs on app host per existing architecture, or on a dedicated VM if inventory is updated)
- **Estimate:** 15 minutes

---

## P1 — SHOULD BE DONE BEFORE HARDWARE

### Infrastructure (jolarca-infrastructure)

### 4. Deploy node_exporter to all targets
- **File:** New task in `ansible/roles/hardening/tasks/main.yml` or new `node_exporter` role
- **Why:** Prometheus scrapes node_exporter on all 7 VMs but nothing installs it. Monitoring will show all targets DOWN.
- **Action:** Add node_exporter installation + systemd unit to the hardening role (runs on every host)
- **Estimate:** 1 hour

### 5. Distribute internal CA certificate
- **File:** `ansible/roles/hardening/tasks/main.yml`
- **Why:** Redis template references `/etc/ssl/certs/jolarca-ca.pem` but no role distributes the CA cert. TLS verification will fail.
- **Action:** Add a task to the hardening role that copies the internal CA cert to `/etc/ssl/certs/jolarca-ca.pem` on all hosts
- **Estimate:** 30 minutes

### 6. Create production group_vars
- **File:** `ansible/inventories/production/group_vars/all/main.yml`
- **Why:** Production needs different variables than staging (different domain, different Vault address, production Stripe keys placeholder)
- **Action:** Create production group_vars with production-specific overrides
- **Estimate:** 30 minutes

### 7. Add Redis connection to app env template
- **File:** `ansible/roles/app/templates/app.env.j2`
- **Why:** The app env template has Celery broker URL but no explicit Redis connection for Django cache backend. The `settings/base.py` references `REDIS_URL` env var.
- **Action:** Add `REDIS_URL={{ vault_redis_url | default('redis://10.10.1.2:6379/0') }}` to app.env.j2
- **Estimate:** 10 minutes

### Legal (jolarca-legal)

### 8. Complete DPIA-001 (Identity and Consent)
- **File:** `dpia/001-identity-and-consent/dpia.md`
- **Why:** Currently a 12-line skeleton. Blocks G1 gate (identity spine evidence). Covers user registration, authentication, identity documents, pgcrypto field-level encryption, consent engine.
- **Action:** Write full DPIA following the template in `docs/DPIA-template.md`. Reference ROPA-001, ROPA-002.
- **Estimate:** 2 hours

### 9. Complete DPIA-002 (AI Processing / LLM Egress)
- **File:** `dpia/002-ai-processing/dpia.md`
- **Why:** Currently a skeleton. Blocks G2 gate. Covers AI-assisted catalog translation, PII guardrails, LLM egress data, special category data in sacred goods descriptions.
- **Action:** Write full DPIA. Reference ROPA-005. Key risk: religious belief data (Art. 9) in AI prompts.
- **Estimate:** 2 hours

### 10. Complete DPIA-004 (Geolocation Search)
- **File:** `dpia/004-geolocation-search/dpia.md`
- **Why:** Currently a skeleton. Blocks G2 gate. Covers PostGIS geolocation queries, location-based search, parcel-locker proximity calculations.
- **Action:** Write full DPIA. Reference ROPA-006. Key risk: location data as personal data under GDPR.
- **Estimate:** 1.5 hours

### Compliance (jolarca-compliance)

### 11. Populate vendor assessments
- **Files:** `vendor-assessments/*/README.md` (6 vendor directories)
- **Why:** All vendor assessment directories contain only README placeholders. ISO 27001 A.15 and SOC 2 CC7.4 require vendor risk assessments.
- **Action:** Complete assessments for: Stripe, DPD, Omniva, Proxmox (hypervisor), Hetzner/offsite backup, Let's Encrypt. Each needs: data processed, DPA status, sub-processor list, TIA if applicable, residual risk.
- **Estimate:** 3 hours

### 12. Populate risk register
- **File:** `risk-register/register.md`
- **Why:** Currently a skeleton. ISO 27001 A.6.1.2 and SOC 2 CC4.1 require a formal risk register.
- **Action:** Populate with risks identified across all DPIAs, threat model, and infrastructure design. Each risk needs: ID, description, likelihood, impact, mitigation, owner, status.
- **Estimate:** 2 hours

---

## P2 — IMPROVES QUALITY

### Application Tests (jolarca)

### 13. Unit tests for `shipping_app`
- **File:** `backend/tests/unit/test_shipping_app.py`
- **Why:** 44 model lines, 0 test files reference it. Shipping logic (parcel-locker selection, carrier pricing) is untested.
- **Estimate:** 2 hours

### 14. Unit tests for `ai_service_app`
- **File:** `backend/tests/unit/test_ai_service_app.py`
- **Why:** 21 model lines, 0 test files reference it. AI guardrails (PII filter, content moderation) are untested — high compliance risk.
- **Estimate:** 2 hours

### 15. Contract tests for `payments_app`
- **File:** `backend/tests/contract/test_payments_api.py`
- **Why:** 107 model lines, only 1 test file references it. Stripe integration is the highest-risk component (PCI DSS scope, financial data).
- **Estimate:** 3 hours

### Infrastructure Hardening (jolarca-infrastructure)

### 16. Add Molecule test for Redis role
- **File:** `ansible/roles/redis/molecule/default/`
- **Why:** 7 of 10 roles have Molecule tests. Redis role (newly created) doesn't.
- **Estimate:** 1 hour

### 17. Add Molecule test for monitoring role
- **File:** `ansible/roles/monitoring/molecule/default/`
- **Why:** Monitoring role doesn't have Molecule tests.
- **Estimate:** 1 hour

### Documentation (jolarca-infrastructure)

### 18. Create RUNBOOK.md
- **File:** `docs/RUNBOOK.md`
- **Why:** Referenced in architecture docs but doesn't exist. Should link to all operational runbooks (backup-restore, incident-response, rollback, staging-deployment, production-deployment).
- **Estimate:** 30 minutes

### 19. Create architecture decision record for Redis placement
- **File:** `docs/adr/0006-redis-placement.md`
- **Why:** Redis runs on app host in current architecture but Day 2/3 prompts suggest a dedicated VM. Decision should be documented.
- **Estimate:** 30 minutes

### Compliance Polish (jolarca-compliance)

### 20. Complete certifications tracker
- **File:** `certifications/README.md`
- **Why:** Currently empty. Should track SOC 2 Type II audit timeline, ISO 27001 certification status, PCI DSS SAQ-A validation.
- **Estimate:** 1 hour

---

## Execution Order (Recommended)

```
Week 1: P0 items (1-3) — unblock production cutover
         ↓
Week 2: P1 infrastructure (4-7) — monitoring + CA + Redis wiring
         ↓
Week 3: P1 legal (8-10) — complete remaining DPIAs
         ↓
Week 4: P1 compliance (11-12) — vendor assessments + risk register
         ↓
Week 5: P2 tests (13-15) — fill test gaps
         ↓
Week 6: P2 infrastructure (16-17) — Molecule tests
         ↓
Week 7: P2 docs (18-20) — runbook index, ADRs, certifications
```

**Total estimated effort:** ~25 hours of focused work.

---

## What CANNOT Be Done Without Hardware

The following require running VMs and must wait for Proxmox:

- Day 1: Host hardening execution
- Day 2: VM provisioning, WireGuard mesh, Vault bootstrap
- Day 3: Application deployment, smoke tests, negative tests
- Restore drill execution
- Monitoring target verification (7/7 UP)
- TLS certificate issuance (internal CA + Let's Encrypt)
- Performance baseline measurement
- Load testing

---

## Acceptance Criteria for "Proxmox-Ready"

Before Proxmox hardware arrives, all of these should be true:

- [ ] All P0 items completed (3/3)
- [ ] All P1 items completed (9/9)
- [ ] At least P2 test items completed (13-15)
- [ ] `git grep -rn 'sk_live'` returns zero across all repos
- [ ] `gitleaks detect --source .` clean on all repos
- [ ] All DPIAs at least `reviewed` status
- [ ] Production inventory exists with placeholder IPs
- [ ] All Ansible roles have Molecule tests
- [ ] `terraform validate` clean on all modules + environments
- [ ] All playbooks pass `ansible-playbook --syntax-check`
