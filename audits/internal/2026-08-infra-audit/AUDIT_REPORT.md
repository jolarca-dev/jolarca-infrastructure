# jol-infrastructure — Independent Infrastructure Audit

- **Audit ID:** 2026-08-infra-audit
- **Date:** 2026-08-15
- **Object:** repository `jol-m-infrastructure` ("The Moat"), commit `0a9ae42` (origin/main), audited on branch `audit/2026-08-infra`
- **Audit team:** Principal Infrastructure Auditor / Senior Security Engineer / ISMS Auditor (independent; did not build this repo)
- **Method:** every claim re-verified by command, test, or file read. Green self-reported tests were re-run, not trusted.

## Safety-constraint compliance (auditor side)

| Constraint | Status |
|---|---|
| No `terraform apply`, no non-check ansible runs, no helm/kubectl against live infra | COMPLIANT — only `fmt/init -backend=false/validate/plan -refresh=false/tflint/checkov/conftest` executed; the single plan file created (`tfplan.audit`) was deleted immediately after `show -json` |
| No Ansible Vault decryption | COMPLIANT — no vault files exist to decrypt (only `.gitkeep`); none read beyond headers |
| No secret values printed | COMPLIANT — all canary material synthetic; findings cite file:line and pattern type only |
| Canary secrets deleted before finalization | COMPLIANT — canaries were created **untracked** on scratch branch `audit/canary-scratch`, detected, removed, and the branch deleted. Zero history contamination (stronger than the required commit-then-delete) |

---

## 1. Executive summary

The repository is a **well-disciplined scaffold** whose documentation honesty is unusually high: nearly every gap is self-declared ("workstream pending", "skeleton", tracked deviations in `security/key-custody.md`). Where content exists (GitHub-org Terraform, OPA policies, secret gates, runbook skeletons), it is structurally sound and mostly passes re-execution.

However, the self-report "tree complete, tests green" is **misleading by omission**: "tests green" is largely *vacuously* green — the Ansible, Kubernetes, monitoring, and backup workstreams contain **zero implementation**, so their gates pass by testing nothing. Two genuine functional defects were found in landed CI logic (drift detection can never alert; the apply path's human-approval gate is not actually enforceable). The secret-hygiene net catches both canary classes via gitleaks/pre-commit, but the bespoke `audit-no-secrets.sh` misses the WireGuard key class — a gap in the exact credential the moat doctrine depends on.

**Final verdict (owner's question "Is jol-infrastructure 100% done?"):**
> **NO.** It is a ~20% scaffold that behaves honestly about what it is, but 4 of 6 designed workstreams (bare metal, Kubernetes, monitoring, backup) are absent, remote encrypted state (ADR-0003) is not landed (state sits unencrypted on a local disk), drift detection is functionally broken (F-03), the apply path lacks an enforceable human gate (F-04), and repo/CODEOWNERS naming must be normalized before push (F-09). Blocking items are listed in `PRE_PUSH_CHECKLIST.md`.

## 2. Verdict per dimension

| Dim | Area | Verdict | Rationale (one line) |
|---|---|---|---|
| A | Conformance | **PASS-WITH-FINDINGS** | Tree matches the declared scaffold design; deviations (codeql disabled, solo-era review gates) are documented; `jol-m-*` naming deviates from canonical fleet names |
| B | Terraform | **PASS-WITH-FINDINGS** | fmt/validate/tflint/checkov clean; all 3 Rego policies proven to fail on bad plans; but remote state + state-bucket module not landed |
| C | Ansible | **PASS-WITH-FINDINGS** | Zero violations (nothing to violate) but the entire designed 00→99 workstream is MISSING; all gates vacuously green |
| D | Kubernetes/Helm | **PASS-WITH-FINDINGS** | No charts, no manifests, no Kyverno/Gatekeeper policies — negative tests impossible because no policy suite exists |
| E | Secret hygiene | **PASS-WITH-FINDINGS** | Tree + full history clean; both canaries caught by gitleaks/pre-commit; `audit-no-secrets.sh` misses WG-key class (F-01) |
| F | Zero-apply safety | **PASS-WITH-FINDINGS** | No ungated apply path exists; but drift-detection logic is dead (F-03, HIGH) and the environment approval gate is not enforceable without Team+ (F-04, HIGH) |
| G | Documentation | **PASS-WITH-FINDINGS** | Runbooks exist, internally consistent, RTO/RPO stated; CODEOWNERS team existence unverifiable locally; isolation boundaries 2/4 have no enforcing mechanism yet |

No dimension FAILED outright; no CRITICAL finding was confirmed (see F-14 nuance on CODEOWNERS).

---

## 3. Dimension A — Conformance

### A.1 Tree-diff verdict table

Design baseline: the external `JOL_Infrastructure_Repo_File_Tree.md` was **not present in the repo or provided**; the audit therefore uses the repo's own declared design (README "Repository map", `ansible/README.md` planned layout, `docs/architecture.md`) as baseline. This assumption is itself logged (F-15).

| Designed component | Verdict | Evidence |
|---|---|---|
| `terraform/environments/{staging,production}` | **PRESENT** | real `.tf` files, lock files, validate green |
| `terraform/modules/github-org` | **PRESENT** | 6 `.tf` files, fully wired |
| `terraform/modules/{dns,gke,iam,networking,state-bucket}` | **MISSING (code)** | each contains only `README.md` — no module implementation |
| `terraform/backends/*.backend.hcl` | **PRESENT / DEVIATED** | exist but hold `REPLACE_ME` bucket names; no backend block active in either environment (local state); tracked by ADR-0003 |
| `terraform/policies/*.rego` (3 policies) | **PRESENT** | proven functional, see B.3 |
| `ansible/` planned layout (`ansible.cfg`, `requirements.yml`, inventories hosts.yml, playbooks 00→99, roles w/ molecule, vault secrets.yml) | **MISSING** | every dir contains only `.gitkeep`; README self-declares "workstream pending" |
| `kubernetes/` (base, helm, overlays, policies) | **MISSING** | only `.gitkeep` placeholders |
| `monitoring/` (prometheus, alertmanager, alerts, grafana) | **MISSING** | only `.gitkeep` + README |
| `backup/` (borg offsite, state backup, restore drill) | **PRESENT (docs) / MISSING (impl)** | procedure docs exist, all marked "reserved/pending" |
| `docs/` (architecture, ADRs 0001–0003, 6 runbooks, threat model, DPIA) | **PRESENT** | all non-empty, internally consistent |
| `security/` (6 documents) | **PRESENT** | all non-empty |
| `scripts/` (bootstrap, audit-no-secrets, check-drift, rotate-vault-password) | **PRESENT** | shellcheck-clean |
| Extras not in baseline | none observed | no stray components |

### A.2 jol-repo-template inheritance

| Inherited artifact | Status |
|---|---|
| README / LICENSE ("INTERNAL USE ONLY" present, line check green) / SECURITY.md / CONTRIBUTING.md / CHANGELOG.md | PRESENT, non-empty |
| Makefile / qodana.yaml / .pre-commit-config.yaml / .editorconfig | PRESENT |
| `.github/`: CODEOWNERS, PR template, issue templates, dependabot | PRESENT |
| Inherited workflow 1: `ci.yml` | PRESENT, active |
| Inherited workflow 2: `compliance-check.yml` | PRESENT, active |
| Inherited workflow 3: `codeql.yml` | **DEVIATED** — renamed to `codeql.yml.disabled`; documented reason (GitHub Advanced Security not purchased). No ADR (F-10) |

### A.3 90/10 doctrine structural check

- Stateful services (PostgreSQL, Vault, MinIO, Borg): **only referenced under `ansible/` + `backup/` docs** — zero stateful data services in any `.tf`. Verified by grep: no `google_sql`, `google_storage_bucket` resource, vault/minio/provider blocks anywhere in `terraform/`. **PASS.**
- WireGuard as single bridge: cannot be verified — no playbooks/roles exist (F-07). Doctrine is documented (`security/isolation-model.md` boundary 2) but unenforced.
- GCP surface in Terraform: currently **zero GCP resources** (GitHub provider only). The "10%" plane is not yet landed.

---

## 4. Dimension B — Terraform (plan-only)

Toolchain: terraform v1.15.8, tflint (ruleset-terraform v0.15.0), checkov (venv), conftest 0.55.0 (OPA 0.67.0). tfsec unavailable (archived upstream — repo made the same decision, `security-scan.yml:36-39`; Trivy covers it in CI).

| Check | Command | Result |
|---|---|---|
| fmt | `terraform fmt -check -recursive terraform` | exit 0 (clean) |
| validate prod | `init -backend=false && validate` | "Success! The configuration is valid." |
| validate staging | same | "Success! The configuration is valid." |
| validate module | same in `modules/github-org` | "Success! The configuration is valid." |
| tflint prod | `tflint --init && tflint --minimum-failure-severity=error` | exit 0, 0 issues |
| tflint staging | same | exit 0; 2 WARNINGs: unused vars `project`, `region` (`variables.tf:5,11`) — intentional reserved scaffold per CI comment; warnings do not block by design. INFO, not a finding |
| checkov | `checkov -d terraform` | 1 passed, 0 failed, **19 skipped** — every skip carries an inline documented justification tied to real `for_each` linkage or deliberate visibility policy; triage: all true-justified, no silent suppression |
| IAM least privilege | grep `roles/(owner|editor|viewer)|serviceAccountUser` + `credentials =` + SA-JSON refs across `terraform/` | **no hits** |
| Workload Identity / no SA JSON keys | grep `"type": "service_account"` | no hits (vacuously — no GCP resources yet) |
| .gitignore state/plan coverage | `git check-ignore -v` on tfstate, tfstate.backup, provider binary | all ignored by rules `*.tfstate`, `*.tfstate.*`, `**/.terraform/*`; `.tfplan` also listed |

### B.3 OPA/Conftest — positive evaluation and negative tests

Fixtures committed under `audits/internal/2026-08-infra-audit/fixtures/` (note: `terraform_version` key intentionally omitted from clean fixture so the repo's own `audit-no-secrets.sh` state-content pattern does not flag audit evidence).

| Fixture | Expectation | Result |
|---|---|---|
| `plan-clean.json` (CMEK bucket, least-priv role, private instance) | pass | **6 tests, 6 passed, 0 failures** |
| real production plan (`terraform plan -refresh=false` → `show -json`) | pass | **6 tests, 6 passed** — policies evaluate real plan JSON |
| `plan-bad-public-ip.json` (access_config + EXTERNAL address) | fail | **2 denies**: "public IP not allowed…", "external static address not allowed…" |
| `plan-bad-iam.json` (roles/editor member, roles/owner binding) | fail | **2 denies**: "basic IAM role roles/editor banned…", "basic IAM role roles/owner banned…" |
| `plan-bad-cmek.json` (tfstate bucket w/o encryption, GKE w/o database_encryption) | fail | **2 denies**: "state bucket … requires CMEK encryption…", "GKE cluster … requires … database_encryption" |

**The policy suite can fail. Negative tests pass.** One code-quality note: rule 1 in `no-basic-iam-roles.rego:13-21` (iterating `members` testing role substring) is dead logic — a banned role string can never be a substring of a member principal; all observed denies came from rule 2 (the `role` attribute). See F-06.

### B.4 Backend isolation

Claim: staging and production backends point to different buckets / CMEK keys / service accounts.
Evidence: `staging.backend.hcl:13` `bucket = "REPLACE_ME-jolm-tfstate-staging"`, `production.backend.hcl:19` `bucket = "REPLACE_ME-jolm-tfstate-production"`. Prefixes differ; comments promise separate CMEK + SA. **But:** neither backend is active (no `backend` block in either environment; explicit comment in `production/main.tf:20-25`), state currently lives **unencrypted on the operator's local disk** (`terraform/environments/production/terraform.tfstate`, 5.1 KB, git-ignored). The `state-bucket` module that would enforce versioning + uniform bucket-level access + CMEK is README-only. Verdict: **designed, not built** — tracked by ADR-0003, hence F-05 is MEDIUM, not HIGH.

---

## 5. Dimension C — Ansible (check-mode only)

Toolchain: ansible-core 2.21.3, ansible-lint (venv). Molecule installed but irrelevant (no roles).

| Check | Result |
|---|---|
| `ansible-lint ansible/` | "Passed: 0 failure(s), 0 warning(s) in **0 files processed** of 10 encountered" — vacuously green |
| `ansible-playbook --syntax-check` | **N/A — zero playbooks exist** |
| Molecule per-role tests | **N/A — zero roles exist** (design mandates per-role tests) |
| Vault structure | `ansible/vault/{production,staging}/` contain only `.gitkeep`; no `$ANSIBLE_VAULT` files exist — header check vacuously satisfied; no decryption attempted |
| Plaintext secret sweep in `ansible/ kubernetes/ monitoring/` (`password:|secret:|private_key|PrivateKey|passphrase`) | **no hits** |
| Inventory hygiene | inventories empty (`.gitkeep` only) — no host overlap possible; also no hosts at all |
| Bootstrap order 00→99 | not verifiable — playbooks absent; planned order documented in `ansible/README.md:24-28` |
| Common-role hardening evidence (sshd, nftables default-deny, fail2ban, unattended-upgrades) | not verifiable — no `common` role exists |

**Verdict:** zero violations, but the entire designed workstream is MISSING (F-07). The CI gate (`ansible.yml`) is honestly built: it self-activates when `playbooks/*.yml` lands. Until then "green" means "absent", which the README discloses.

---

## 6. Dimension D — Kubernetes / Helm

helm/kubeconform not installed locally **and nothing to run**: `kubernetes/{base,helm,overlays/*,policies}` contain only `.gitkeep`.

- `helm lint` / `helm template`: **N/A — zero charts**.
- Kyverno/Gatekeeper self-consistency + negative tests (`:latest`, privileged, missing probes): **impossible — no policy suite exists**. An untestable policy layer is, by definition, decoration-not-yet-built; logged as F-08.
- Security contexts, HPA/PDB: N/A per chart (no charts).

---

## 7. Dimension E — Secret-hygiene sweep

### E.1 Full-tree scans (current tree + full history)

| Scan | Result |
|---|---|
| `gitleaks detect --source . --no-banner --redact` (8.30.1, git mode, 16 commits) | "no leaks found" |
| Manual regex sweep: PEM headers, `"type": "service_account"`, DB connection strings with passwords, `PrivateKey =`, borg passphrase patterns | **no hits** (repo tree) |
| `scripts/audit-no-secrets.sh` on clean clone (no local harness) | "AUDIT CLEAN" exit 0 |
| `scripts/audit-no-secrets.sh` in auditor working tree | fails on `.venv/` third-party test fixtures (cryptography/ecdsa) and on this audit's own plan fixture — the script does not exclude `.venv`/`venv`. CI (clean checkout) unaffected. F-02 |

### E.2 Canary negative test (scratch branch, zero history contamination)

Canaries (synthetic): fake WireGuard `PrivateKey = …=` in `canary-wg.conf`, fake RSA PEM in `canary-key.pem`. Created untracked on branch `audit/canary-scratch`; branch deleted after the test.

| Gate | WG key canary | PEM canary |
|---|---|---|
| gitleaks (dir mode) | **CAUGHT** (`generic-api-key`) | **CAUGHT** (`private-key`) |
| gitleaks (pipe mode) | CAUGHT | CAUGHT |
| pre-commit `gitleaks` hook | **CAUGHT** ("leaks found: 2") | CAUGHT |
| pre-commit `detect-private-key` | not caught (PEM-only detector — by design) | **CAUGHT** |
| `audit-no-secrets.sh` | **NOT CAUGHT** (no WG pattern) | CAUGHT (filename + content) |

Both canary classes are caught by pre-commit and CI security-scan (gitleaks). **But** the bespoke net (`audit-no-secrets.sh`) has no WireGuard pattern — the single credential class that protects the only bridge between planes. F-01. (Not CRITICAL only because a compensating detector exists in both remaining gates.)

---

## 8. Dimension F — Zero-apply safety

Apply-verb sweep across all workflows, scripts, Makefile (`terraform apply|ansible-playbook|kubectl apply|helm upgrade|helm install`): exactly **two** hits:

1. `ansible.yml:46` — `ansible-playbook --syntax-check` (read-only by definition). SAFE.
2. `terraform.yml:99` — `terraform apply -auto-approve` inside job `apply`, which is conditioned on `github.event_name == 'workflow_dispatch'` **and** `environment: ${{ inputs.environment }}` (terraform.yml:83-99). An explicit environment gate exists → not an *ungated* apply path → not CRITICAL per the severity model. **However**, `security/key-custody.md` deviation 2 admits required reviewers cannot be enforced without GitHub Team+ — the gate is currently *structural only*. Combined with deviation 1 (read and write tokens are the **same classic PAT**), a single token leak reaches an auto-approve apply. F-04 (HIGH).
3. `push` events run only `validate`/plan; no workflow applies on push. No `id-token: write` (WIF) anywhere; no GCP credentials in any workflow — drift/plan jobs hold only `TF_GITHUB_TOKEN_READONLY`. Credential scoping vs jol-marketplace: secrets are repo-scoped by documented design (`terraform.yml:4-6`) — repo secrets are unreachable by other repos' CI. Consistent with isolation rule 2. (Repo settings themselves must be verified post-push — checklist step 3.)
4. `drift-detection.yml`: runs `terraform plan -lock=false -detailed-exitcode` (read-only) — **but the step never sets `exitcode` into `$GITHUB_OUTPUT`**, so `steps.drift.outputs.exitcode` is always empty: the issue-creation condition `== '2'` never fires and the final `!= '0'` check always fails the job. Drift detection **cannot succeed and cannot alert**. F-03 (HIGH).

---

## 9. Dimension G — Documentation & consistency

### G.1 CODEOWNERS handles

| Path | Owner handles |
|---|---|
| `*` (default) | `@journeyoflife-org/infra-operators` |
| `/security/`, `/terraform/policies/`, `/kubernetes/policies/`, `/ansible/vault/`, `/docs/runbooks/state-compromise.md` | `@journeyoflife-org/security` |
| `/terraform/backends/`, `/scripts/`, `/.github/workflows/` | `@journeyoflife-org/infra-operators` + `@journeyoflife-org/security` |
| `/security/pci-dss-scope.md` | `@journeyoflife-org/security` + `@journeyoflife-org/compliance` |
| `/security/access-review.md` | `@journeyoflife-org/compliance` |
| `/docs/adr/`, `/.github/actions/` | `@journeyoflife-org/infra-operators` |

Handles follow consistent org-team naming and are **not literal placeholders** — but team existence is **unverifiable from a local clone** (org teams are private; no authenticated org API access available to the audit). If any team does not exist, CODEOWNERS silently matches nobody and review routing dies — that condition would be CRITICAL. Therefore F-14 is recorded as *unverified-pending-checklist*, and checklist step 2 is push-blocking.

### G.2 Cross-repo naming

`grep -RIl "jol-m-"` hits 19 tracked files (README, LICENSE, Makefile, pyproject.toml, CHANGELOG, CONTRIBUTING, SECURITY.md, security/*, docs/adr/README.md, threat-model, state-compromise runbook, `terraform/modules/github-org/{variables,main}.tf`, terraform/README). The fleet map itself (`variables.tf:15-37`) hard-codes `jol-m-marketplace/compliance/legal/data/infrastructure`. Canonical doctrine requires `jol-marketplace` / `jol-compliance` / `jol-legal`, and this repo renamed to `jol-infrastructure`. Note the collision flagged by the module's own comment: church-platform infra is already called `jol-infrastructure` (`versions.tf:4-6`) — the rename runbook must resolve that namespace collision first. F-09 includes the rename runbook (see `PRE_PUSH_CHECKLIST.md` step 1).

### G.3 Runbooks & DR targets

All six designed runbooks exist: bootstrap-from-zero, vault-sealed, postgres-failover, wireguard-key-rotation, state-compromise (+ github-token-rotation, ACTIVE). RTO ≤ 4h / RPO ≤ 15 min stated in `backup/restore-drill.md:3`, `postgres-failover.md:5-6`, `architecture.md:50`, encoded in `monitoring/README.md`. Skeleton statuses honestly declared. Dead-link scan across all `.md`: **no dead relative links**.

### G.4 Isolation model — rule-to-enforcement traceability

| Boundary (isolation-model.md) | Enforcing mechanism in-repo | Traceable? |
|---|---|---|
| 1. Marketplace ↔ church-platform | Separate repos; repo-scoped CI secrets (`terraform.yml:4-6`); CODEOWNERS | YES |
| 2. Bare metal ↔ GCP via WireGuard only | none yet (playbooks pending); doc-level only | **NO → F-12** |
| 3. GKE ↔ internet | `no-public-ips.rego` (proven to fail bad plans) | YES |
| 4. Bare metal ↔ internet via nginx edge only | none yet (60-nginx-edge pending) | **NO → F-12** |
| 5. Operator ↔ production | branch protection (terraform-managed), env-gated apply, status checks | YES (solo-era caveats, F-11) |
| 6. Secrets ↔ everything | `.gitignore` rules, pre-commit (detect-private-key + gitleaks), CI gitleaks, `audit-no-secrets.sh`, vault dir structure | YES (gap F-01) |

---

## 10. Findings register

| ID | Dim | Severity | Location | Claim vs. Evidence | Remediation | Owner |
|---|---|---|---|---|---|---|
| F-01 | E | MEDIUM | `scripts/audit-no-secrets.sh:37-42` | Claims to be "the pre-push net" for all secret classes; has no `PrivateKey =` (WireGuard) pattern — WG canary passed through | Add WG pattern (`PrivateKey[[:space:]]*=[[:space:]]*[A-Za-z0-9+/]{42,44}=`) + fixture test | security |
| F-02 | E | LOW | `scripts/audit-no-secrets.sh:25,44` | Script scans `.venv/` third-party fixtures → `make check` fails for any operator with the documented Python harness; CI clean-checkout unaffected | Prune/exclude `.venv` and `venv` in `find` and `grep` | infra-operators |
| F-03 | F | HIGH | `.github/workflows/drift-detection.yml:31,43` | Claims drift opens an issue; `steps.drift.outputs.exitcode` is never written to `$GITHUB_OUTPUT` → alert never fires and every scheduled run fails (exit 1) forever | Capture rc: `rc=0; terraform plan … -detailed-exitcode \|\| rc=$?; echo "exitcode=$rc" >> $GITHUB_OUTPUT` | infra-operators |
| F-04 | F | HIGH | `.github/workflows/terraform.yml:83-99`; `security/key-custody.md` deviations 1+2 | Apply path has `environment:` gate but no enforceable required reviewers (no Team+), and read/write tokens are the same classic PAT → one leaked token = unreviewed auto-approve apply | Split read/write fine-grained PATs now; acquire Team+ or document accepted risk with expiry date; restrict `workflow_dispatch` to named operators | security |
| F-05 | B | MEDIUM | `terraform/backends/*.backend.hcl:13,19`; `terraform/modules/state-bucket/README.md` | Claims CMEK/versioned/isolated remote state (ADR-0002/0003); backends hold `REPLACE_ME`, no backend block active, state-bucket module has no code; live state is an unencrypted local file | Land state-bucket module + bootstrap.sh naming, migrate per ADR-0003, delete local exception in audit-no-secrets.sh after migration | infra-operators |
| F-06 | B | LOW | `terraform/policies/no-basic-iam-roles.rego:13-21` | Rule 1 tests banned-role substring inside member principals — dead logic, can never fire (rule 2 provides real coverage) | Delete rule 1 or rewrite for `google_*_iam_policy` documents | security |
| F-07 | C | MEDIUM | `ansible/**` | Design mandates 00→99 playbook chain, per-role molecule, vault files; tree contains zero ansible content; gates green by absence; deferral not captured as an ADR | Land workstream per `ansible/README.md`, or record deferral in ADR-0004 | infra-operators |
| F-08 | D | MEDIUM | `kubernetes/**` | Designed Helm/Kustomize/policy layers absent; negative testing impossible (no policies to exercise) | Land first chart + policy suite before any GKE workload | infra-operators |
| F-09 | A/G | MEDIUM | repo name; `terraform/modules/github-org/variables.tf:15-37`; 19 tracked files | Canonical naming is `jol-marketplace/compliance/legal` + this repo as `jol-infrastructure`; fleet map and docs hard-code `jol-m-*`; collision with church-platform `jol-infrastructure` must be resolved | Execute rename runbook (checklist step 1): resolve namespace collision, rename repo, update fleet map + 19 files atomically | security + infra-operators |
| F-10 | A | LOW | `.github/workflows/codeql.yml.disabled` | 1 of 3 inherited template workflows disabled; reason documented in-file but no ADR | Add ADR-0005 (or restore) | infra-operators |
| F-11 | A | MEDIUM | `terraform/environments/production/main.tf:58-59` | Branch protection runs with 0 approving reviews + no CODEOWNERS reviews; deviation tracked in `key-custody.md` with activation checklist | Raise to ≥1 + re-enable on second-operator onboarding (checklist exists in CONTRIBUTING.md) | security |
| F-12 | G | MEDIUM | `security/isolation-model.md:18,20` | Boundaries 2 and 4 declared doctrine but have zero in-repo enforcement mechanism today | Resolves automatically when F-07 lands; until then mark doctrine coverage as partial in access review | security |
| F-13 | B | INFO | `terraform/environments/staging/variables.tf:5,11` | tflint warns unused vars; intentional reserved scaffold, CI fails only on errors | No action (documented intent) | — |
| F-14 | G | UNVERIFIED→push-blocking | `.github/CODEOWNERS` | Teams `infra-operators/security/compliance` cannot be verified to exist from a local clone; nonexistent team = silent routing death (would be CRITICAL) | Checklist step 2: org admin verifies all three teams exist with correct membership **before** push | security |
| F-15 | A | LOW | audit baseline | External design doc `JOL_Infrastructure_Repo_File_Tree.md` not in repo; audit used in-repo design docs as baseline | Attach the approved design doc to the audit record / repo | compliance |

Severity distribution: CRITICAL 0 · HIGH 2 · MEDIUM 6 · LOW 4 · INFO 1 · UNVERIFIED(push-blocking) 1.

---

## 11. Evidence appendix (commands executed)

| # | Command | Outcome (summary) |
|---|---|---|
| 1 | `git ls-files \| sort` | 89 tracked files enumerated (tree basis) |
| 2 | `git check-ignore -v <tfstate,backup,provider binary>` | all matched `.gitignore` rules |
| 3 | `terraform version` | v1.15.8 |
| 4 | `terraform fmt -check -recursive terraform` | exit 0 |
| 5 | `terraform init -backend=false && terraform validate` × {production, staging, modules/github-org} | 3× "Success! The configuration is valid." |
| 6 | `tflint --init && tflint --minimum-failure-severity=error` × {production, staging} | prod exit 0/0 issues; staging exit 0/2 warnings (F-13) |
| 7 | `checkov -d terraform` | 1 pass / 0 fail / 19 documented skips |
| 8 | grep IAM basic roles / SA keys across `terraform/` | no hits |
| 9 | `terraform plan -refresh=false -out=tfplan.audit` + `show -json` + `conftest test` (production root) | plan produced; 6/6 policy tests pass; plan file deleted |
| 10 | `conftest test fixtures/plan-*.json --policy terraform/policies --all-namespaces` ×4 | clean=6/6 pass; public-ip=2 denies; iam=2 denies; cmek=2 denies |
| 11 | `gitleaks detect --source .` (git mode, full history) | 16 commits, no leaks |
| 12 | Manual regex sweep (PEM/SA-JSON/connstrings/WG/borg) | no hits in repo tree |
| 13 | `bash scripts/audit-no-secrets.sh` on clean clone | "AUDIT CLEAN" exit 0 |
| 14 | Canary test: gitleaks dir+pipe, pre-commit `detect-private-key`, pre-commit `gitleaks` hook, audit-no-secrets.sh | see §7 E.2 table |
| 15 | `ansible-lint ansible/` | 0 failures in 0 processed files |
| 16 | `ansible --version` | core 2.21.3 (syntax-check/molecule N/A — no content) |
| 17 | `shellcheck scripts/*.sh` | clean |
| 18 | grep apply-verbs across workflows/scripts/Makefile | 2 hits, both analyzed (§8) |
| 19 | grep `RTO\|RPO` docs/backup/monitoring | targets stated consistently |
| 20 | grep `jol-m-` across tree | 19 files (F-09) |
| 21 | Python dead-link scan over all `*.md` | no dead relative links |
| 22 | `grep -c "INTERNAL USE ONLY" LICENSE` | 1 |
| 23 | Vault structure inspection (`find ansible/vault -type f`, header read) | only `.gitkeep`; no decryption performed |
| 24 | Canary cleanup: `git reset`, file deletion, `git branch -D audit/canary-scratch` | verified gone; branch list shows only `main` + `audit/2026-08-infra` |

*End of report.*
