# PRE-PUSH CHECKLIST — jol-infrastructure scaffold

Ordered runbook. Steps 1–3 are **push-blocking**; do not push the scaffold branch
before they are green. Findings referenced: `AUDIT_REPORT.md` §10.

## 0. Pre-flight (already satisfied by this audit)

- [x] Audit report + findings register committed on `audit/2026-08-infra`
- [x] No CRITICAL findings confirmed; no canary material left in any branch or history
- [x] Zero apply/decrypt executed during audit

## 1. Rename to `jol-infrastructure` (F-09)

Canonical fleet naming: `jol-marketplace`, `jol-compliance`, `jol-legal`, and this
repo as `jol-infrastructure`. Execute atomically in one change record:

1. **Resolve the namespace collision first**: `terraform/modules/github-org/versions.tf:4-6`
   states church-platform infra is already called `jol-infrastructure`. Obtain written
   confirmation of what the church-platform repo is actually named; if the name is taken,
   this rename cannot proceed without renaming that repo or choosing an ADR-approved
   alternative — record the decision as a new ADR before touching anything.
2. Rename the GitHub repository (Settings → General → Rename). GitHub redirects clone URLs.
3. Update the Terraform fleet map `terraform/modules/github-org/variables.tf:15-37`:
   `jol-m-marketplace → jol-marketplace`, `jol-m-infrastructure → jol-infrastructure`,
   `jol-m-compliance → jol-compliance`, `jol-m-legal → jol-legal`, `jol-m-data → jol-data`
   (rename is destructive for the resource key — plan first, expect destroy/create unless
   `moved` blocks are added; use `terraform state mv` discipline per CONTRIBUTING.md).
4. Sweep the 19 tracked files containing `jol-m-` (README.md, LICENSE, Makefile,
   pyproject.toml, CHANGELOG.md, CONTRIBUTING.md, SECURITY.md, security/isolation-model.md,
   security/access-review.md, security/pci-dss-scope.md, docs/adr/README.md,
   docs/threat-model.md, docs/runbooks/state-compromise.md, terraform/README.md,
   terraform/modules/github-org/{variables.tf,main.tf}, .idea/modules.xml):
   `grep -RIl "jol-m-" . --exclude-dir=.git --exclude-dir=.terraform --exclude-dir=.venv`
   must return empty afterwards (bucket-name prefixes `jolm-tfstate-*` in
   backends/policies are naming-convention identifiers — decide per ADR whether they
   follow; recommend keeping until state buckets land, then rename in the same ADR).
5. Re-run `make check` + full CI; verify `terraform plan` shows only the expected
   fleet-map changes.

## 2. Real CODEOWNERS teams (F-14)

Org admin, with the replacement table below, verifies in GitHub → org → Teams:

| CODEOWNERS handle | Must exist | Minimum membership | Verified by / date |
|---|---|---|---|
| `@journeyoflife-org/infra-operators` | YES | ≥ 1 operator (≥ 2 post-onboarding) | ______ |
| `@journeyoflife-org/security` | YES | security lead (+ second custodian when onboarded) | ______ |
| `@journeyoflife-org/compliance` | YES | compliance owner | ______ |

If any team is missing: create it **or** replace the handle per this table before push.
A CODEOWNERS entry matching a nonexistent team routes to nobody — silent failure.

## 3. Confirm GitHub repo settings

- [ ] Repository **private** (verify in Settings; do not trust memory)
- [ ] **Forking disabled** (Settings → General → "Allow forking" off) — isolation-model.md
      forbids mirroring; state/secret excerpts must not be forkable
- [ ] **Wiki disabled**, Projects disabled unless needed (reduce unreviewed-content surfaces)
- [ ] Secret scanning + push protection enabled (private-repo availability per plan)
- [ ] Audit log export scheduled (org level)
- [ ] No org-level secrets reachable from this repo's workflows (isolation rule: repo-scoped
      secrets only — `terraform.yml:4-6`)

## 4. Push scaffold branch

- [ ] Push `audit/2026-08-infra` (or the prepared scaffold branch) to origin
- [ ] Confirm no new findings from push-time secret scanning

## 5. Branch protection + required checks + vulnerability reporting

- [ ] Protect `main`: no force-push, no deletion, `enforce_admins = true` (matches
      `branch-protection.tf` — the Terraform-managed policy is source of truth; if applied
      manually first, reconcile with the plan afterwards)
- [ ] Required status checks: `ci`, `security` (names pinned by `ci.yml:2`, `security-scan.yml:4`)
- [ ] Require conversation resolution (matches module)
- [ ] Enable **private vulnerability reporting** (Security tab)
- [ ] Solo-era deviation (0 approvers) remains tracked in `security/key-custody.md` —
      confirm the activation checklist date target in CONTRIBUTING.md (F-11)

## 6. PR with all workflows green

- [ ] Open PR from scaffold branch; required checks `ci` + `security` pass
- [ ] `drift-detection` fix (F-03) lands **in this PR** — pushing with a known-dead
      scheduled workflow fails the "tests green" claim on day one
- [ ] `terraform.yml` plan job renders a plan comment (read-only token only)

## 7. Security-lead sign-off on Dimensions E + F

- [ ] Security lead reviews AUDIT_REPORT.md §7 (canary evidence) and §8 (zero-apply evidence)
- [ ] Explicit sign-off recorded on the PR (comment + approval) — the two-person rule's
      interim substitute while solo-era deviation 3 stands
- [ ] F-04 remediation date committed (split read/write PATs; Team+ decision)

## 8. Merge

- [ ] Squash-merge (repo default per `main.tf:29-31`); delete branch
- [ ] Verify post-merge `main` run of `ci` + `security` green

## 9. Tag

- [ ] Tag `v0.1.0-scaffold` (or per CHANGELOG convention), annotated, listing the
      audit ID `2026-08-infra-audit` and the open findings (F-05..F-12) as known state
- [ ] Record tag + audit pointer in CHANGELOG.md and in the compliance evidence repo

---

### Residual (non-blocking) items to schedule after push

- F-01 WG pattern in `audit-no-secrets.sh` · F-02 `.venv` exclusion · F-05 remote state
  landing (ADR-0003) · F-06 dead Rego rule · F-07 ansible workstream or deferral ADR ·
  F-08 first chart + policy suite · F-10 codeql ADR · F-12 doctrine enforcement as F-07 lands
