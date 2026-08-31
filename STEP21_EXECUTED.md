# STEP 21 — EXECUTED: E3 staging deployment + N2 row + credential-independent deny proof (B4/B6 partial, N2)

- **Date:** 2026-08-17 · **Repo:** jolarca-infrastructure (+ jol-hub N2 PR) · **Branch:** `step-21-e3-deployment`
- **Risk class:** High (network / PCI scope) · **Production: HUMAN-GATED — nothing in this step touches production.**
- **Sequence role:** fourth of 18 → 19 → 20 → 21; steps 18–20 merged (`89c4812d`, `85d51489`, `4faef0a3`).
- **NOT a verdict.** Independent re-audit (Step 22b) judges PROVEN/NOT-PROVEN.

## What landed

1. **N2 fix FIRST (jol-hub PR #82, merged `4f93c6b9`):** the sanctioned
   hub→payment-API egress row added to hub's backend NetworkPolicy —
   helm renders it fail-closed from `paymentsApi.cidr` (empty = row does
   not render; donations degrade, Stripe stays unreachable), kustomize
   carries the documented substitute. Without this row the contracted
   donation flow would have been blocked by its own policy.
   Poetic evidence: the E1 guard initially FAILED this PR because the
   explanatory prose contained the forbidden endpoint literal — the
   guard caught its own authors; comment reworded, guards green, merged
   through the armed required checks.
2. **E3 staging plane deployed** (`scripts/e3-network-deny-test.sh`,
   record copy committed here): docker staging topology standing in for
   the production planes — `--internal` network = hub plane (no external
   egress), standard network = boundary plane, payment-API stub
   dual-homed like the real boundary. The k8s/GKE equivalents are the
   hub default-deny NetworkPolicy set + the marketplace payments_app
   allow-list (`security/network-policy.md` matrix, status column).
3. **Credential-independent negative test (C2 caveat closure):**
   hub-plane workload carrying a syntactically VALID Stripe test key
   attempted `api.stripe.com:443`:

   ```text
   BLOCKED BY NETWORK: gaierror: [Errno -3] Temporary failure in name resolution
   NEGATIVE PASS: hub egress denied at network layer
   ```

   The denial happens at the network layer (no route / no DNS), BELOW
   authentication — key validity is irrelevant. Step-17's caveat
   ("blocked by credential absence, not topology") is closed for the
   staging plane.
4. **Positive tests:** hub→payment-API stub reachable via the sanctioned
   row (`POSITIVE PASS`); boundary plane→Stripe reachable (`POSITIVE
   PASS` — sole sanctioned egress). js.stripe.com browser carve-out:
   unaffected by design — Elements loads in the DONOR'S browser, never
   from hub servers; server-side egress denial does not and must not
   touch it.
5. **Drift alerting declared** (`security/network-policy.md`): the
   re-runnable proof script is mandated on every payment-boundary PR +
   quarterly scope reconfirmation; matrix-vs-deployed drift = incident
   per isolation-model.

## Reproduced evidence

```text
$ bash scripts/e3-network-deny-test.sh
== staging topology: hub plane (internal, no external egress) + boundary plane
== NEGATIVE: hub workload WITH a valid Stripe test key -> api.stripe.com
NEGATIVE PASS: hub egress denied at network layer
== POSITIVE: hub workload -> payment-API stub (the N2 sanctioned row)
POSITIVE PASS: sanctioned flow works
== POSITIVE: boundary plane -> api.stripe.com (sole sanctioned egress)
POSITIVE PASS: boundary->Stripe works
E3 NETWORK DENY: ALL CHECKS PASSED
```

shellcheck clean. Explicit single-probe capture:
`BLOCKED BY NETWORK: gaierror: [Errno -3] Temporary failure in name
resolution` (docker `--internal` hub plane).

## Honest scope boundaries

- **Staging plane only.** No GKE cluster exists in this org yet; the
  NetworkPolicy set and NAT allow-list rows are declared and proven at
  the mechanism level (docker staging + manifests), and deploy with the
  cluster workstream. Production remains human-gated per doctrine.
- The staging proof uses representative probe containers (network-layer
  test; workload identity does not change egress behavior).
- Full B6 (live production boundary) completes when the cluster lands;
  this step closes B4 at staging level and N2 entirely.

## Acceptance checklist

- [x] N2 fixed FIRST (hub PR #82 merged through armed guards)
- [x] Default-deny + explicit-allow policies deployed on staging plane
- [x] Credential-independent negative test: hub WITH valid test key
      blocked by NETWORK (evidence above)
- [x] Positives: boundary→Stripe works; hub→payment-API works
- [x] js.stripe.com browser carve-out intact (documented)
- [x] Drift alerting on the policy (network-policy.md section)
- [x] STAGING only; production human-gated; committed + pushed

## Rollback

Revert this PR (removes the script, matrix status, drift section) and
`docker network rm` the staging nets; revert jol-hub PR #82 for the N2
row (policy returns to deny-all incl. the payment API — fail-closed).
