# STEP 22 — Payment Boundary Re-Audit (Model A): Live Verification Attempt

- **Persona:** independent audit (paranoid, evidence-first). Creed: Step 17
  said NOT PROVEN; this re-audit either proves Model A with live evidence
  or names the remaining blockers. No claim passes without a reproduced
  check. No self-attestation accepted — including of Steps 18–21.
- **Date:** 2026-08-17
- **Prior audit:** `STEP17_AUDIT.md` (sha256
  `86f028d28a74c954911edec023406ad5b5a0f7de4b297f0171b0e3dc370c9f08`)

## Threshold finding — Steps 18–21 did not happen

Before any control was re-run, the audit verified the premise that a
remediated, implemented boundary exists. It does not:

| Check | Command / evidence | Result |
|-------|--------------------|--------|
| Step artifacts | `ls /opt/jol-m/repos/*/STEP* /opt/jol/repos/jol-hub/STEP*` | only STEP0, STEP10, STEP17 exist — NO STEP18/19/20/21 anywhere |
| Remediation commits | `git log --oneline -5` in all four repos | latest commits: CodeQL CI fix (marketplace), CODEOWNERS governance (hub), build-audit hygiene (compliance), CMEK ordering (infra) — ZERO payment-boundary remediation commits |
| Live boundary | `docker ps`, `ss -ltn` | marketplace test-db + test-redis up; NO application container, NO listener on 8000/8080; `kubectl` → connection refused (no cluster reachable) |

**There is no live boundary to audit.** Controls below were re-verified
against the current code/CI/manifest state anyway — every Step-17 result
reproduced.

---

## Per-control re-verification

### C1 Ownership (code) — PARTIAL PASS (unchanged)

- Marketplace Stripe usage still contained to `apps/payments_app/`
  (grep re-run: only dependency manifests outside it). ✓
- Fleet key entropy scan (`sk_(live|test)_` ≥20 chars): **0 hits**. ✓
- Hub app code: still zero Stripe imports. ✓
- **PB-01…PB-06 all still present, byte-identical, same file:line:**
  `stripe==14.4.0` (django/requirements.txt:83), `stripe>=14.0`
  (requirements.txt:49), `STRIPE_SECRET_KEY` plumbing
  (settings/base.py:706, secrets.py:21/224-227, vault.py:25),
  infra secrets (`sk_live_CHANGE_ME` k8s secrets.yaml:32, tf main.tf:81),
  direct-integration `payment-providers.yml` (stripe enabled:true),
  inverted test (test_compliance.py:929), `.env:39` placeholder.

### C1 Ownership (CI guard, "Step 19") — FAIL

```bash
grep -rnE 'payment.boundary|check-payment|stripe|dependency.guard' jol-hub/.github/workflows/*.yml   # → 0 hits
gh api repos/journeyoflife-org/jol-hub/branches/main/protection/required_status_checks --jq '.contexts'   # → []
```

No boundary guard in any hub workflow. Worse — **new finding N1:** hub's
branch protection has ZERO required status checks, so even a wired guard
would not be merge-blocking today. E1/E2: NOT OPERATIONAL.

### C1 Ownership (network, "Step 21") — DESIGNED, NOT ENFORCED

Progress since Step 17: hub now carries default-deny NetworkPolicy
manifests (`infra/kubernetes/networking/network-policy.yaml` + helm
template): namespace deny-all, backend egress allow-list = DB 5432 +
redis 6373 + DNS 53 only — **no 443/external egress row exists, so
api.stripe.com is topologically unreachable under these manifests.**
The manifest shape is E3-sufficient. But:

- No cluster is deployed (`kubectl` → connection refused); nothing enforces anything.
- **New finding N2:** the backend egress allow-list has NO row for the
  sanctioned hub→payment-API flow (443). Deployed as-is, it would block
  the contracted flow too — the row must be added (network-policy.md
  matrix) when the boundary deploys.
- The credential-independent negative test (hub WITH a valid key, blocked
  by topology) **cannot be run**: there is no hub runtime.

### C2 SAQ-A + hostile attempt — PASS-by-absence AGAIN (caveat OPEN)

Re-run from hub's own venv with the only key material in hub:

```text
BLOCKED: AuthenticationError: Invalid API Key provided: sk_test_****…
```

Identical to Step 17: blocked by credential absence, not topology.
PB-06's placeholder is still the only credential. The Step-17 caveat is
**unresolved** — it closes only when the C2 attempt fails on E3 in a
deployed hub runtime.

### C3 Contract regression — NOT EXECUTABLE (unchanged)

`payments_app/urls.py` still exposes only the Stripe webhook; no
`/internal/v1`, no mTLS/HMAC layer, no caller registry, no forwarding;
no contract tests anywhere (`find tests -name '*contract*' -o -name
'*payment*'` → empty). Nothing to run the suite against.

### C4 Webhook integrity — CODE-LEVEL ONLY; DEFECT UNFIXED

`webhooks.py:50` still `except ValueError:` only —
`SignatureVerificationError` is not a ValueError subclass, so forged
webhooks still yield 500, not 400. Dedup logic unchanged
(code-verified). No live endpoint for replay/forwarding drills.

### C5 Revenue attribution — FAIL (unchanged)

`grep product payments_app/{models,services}.py` → 0 hits. No `product`
field, no attribution metadata, no finance-mart contract artifact.

### C6 Degraded mode — NOT EXECUTABLE

No running boundary to take down; the drill Step 17 deferred remains
deferred for the same reason.

---

## Additional findings

- **N3 — evidence custody gap:** the Step-17 compliance artifacts (scope
  statement, archived report, register rows) were NEVER COMMITTED —
  `git status` in jolarca-compliance still shows them as untracked/modified.
  "Immutable, hash-pinned" is currently false for the prior audit too.
  Nothing is gate evidence until merged through protected branches.

## Blockers (the remaining work, owned)

| # | Blocker | Owner | Closes |
|---|---------|-------|--------|
| B1 | Purge PB-01…PB-06 from jol-hub (the Step-18 work) | Platform | RSK-006 |
| B2 | Wire E1/E2 guards into hub CI AND add them to branch-protection required checks (N1) | Platform | RSK-007 |
| B3 | Implement `/internal/v1` per contract (endpoints, mTLS, HMAC, idempotency, caller↔product binding, `product` attribution, signed forwarding) + consumer-driven contract tests | Marketplace | RSK-009, C3, C5 |
| B4 | Deploy a hub runtime with the NetworkPolicy set enforced; re-run C2 hostile attempt — must fail on topology; add the hub→payment-API 443 egress row (N2) | Infra | RSK-008 |
| B5 | Fix webhook forgery → 400 (exception-class handling) | Marketplace | Step-17 defect |
| B6 | Bring up the boundary (app containers/cluster) so C3/C4-live/C6 drills can execute | Marketplace/Infra | C3, C4, C6 |
| B7 | Commit Step-17 + Step-22 evidence through protected branches (N3) | Compliance | evidence integrity |
| B8 | Route donation VAT/receipt question to jolarca-legal + tax advisor (still open) | Compliance/Legal | RSK-011 |

## Loop closure — what this re-audit did NOT change, and why

- **PCI scope statement:** unchanged. It already reads "CONDITIONAL on
  E1–E3 being operational" — the condition is still unmet; marking it
  PROVEN now would be false certification.
- **Risk register:** RSK-006…RSK-011 remain OPEN — every underlying
  finding reproduces. No risk was closed because no control changed.
- **G3 gate:** NOT CLEARED. Checklist items remain unchecked; the
  gate-evidence directory gains only this re-audit (archived under
  `audits/internal/`, hash-pinned, in jolarca-compliance).

## ONE-SENTENCE VERDICT

**Model A single-payment-boundary remains NOT PROVEN — Steps 18–21 were
never executed (no commits, no step artifacts, and all six Step-17
residue findings reproduce byte-identically), no live boundary exists on
which contract, webhook, or degraded-mode controls could be verified,
E3 exists only as correct-but-undeployed manifests, and G3 stays
BLOCKED — the first real donation is NOT authorized until blockers
B1–B8 are closed and this audit is re-run against the live system.**
