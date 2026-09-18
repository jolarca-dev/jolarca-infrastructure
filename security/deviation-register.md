# Deviation Register — jolarca-dev organization

**Owner:** Principal Engineer · **Last updated:** 2026-09-17  
**Scope:** All 6 repositories in the `jolarca-dev` GitHub org  
**Rule:** Every known gap between current posture and target security baseline, with rationale, risk, and remediation owner.

---

## Active Deviations

| ID | Severity | Repo(s) | Deviation | Rationale | Risk | Remediation | Owner |
|----|----------|---------|-----------|-----------|------|-------------|-------|
| DEV-01 | Medium | All | `required_approving_review_count = 0` | Solo-era: only one engineer. Branch protection enforces linear history, signed commits, and CI gates instead. | A single person can merge their own code. Mitigated by mandatory CI + pre-commit + gitleaks. | Close when second engineer is onboarded. | Principal |
| DEV-02 | Low | infra, compliance, data, legal, .github | CodeQL disabled (`codeql.yml.disabled`) | CodeQL requires a paid plan for private repos or is redundant with gitleaks + trivy for IaC-focused repos. | SAST coverage gap for non-jolarca repos. jolarca (the app) has CodeQL active. | Enable when GitHub plan supports it or when non-IaC code lands in these repos. | Principal |
| DEV-03 | Low | All | All repos are `visibility: public` | "Public is correct; fix the IaC" — no proprietary secrets in source; gitleaks + .gitleaksignore guard against accidental leaks. | Any future proprietary config must be vault-encrypted, not committed. | No action needed — public is the intended posture. | Principal |
| DEV-04 | ~~Critical~~ → Medium | infra | ~~Molecule tests never execute in CI (B17)~~ | CI pipeline infrastructure fixed (working-directory, docker driver, community.docker, ansible-core<2.18, role discovery). Remaining: roles assume `/etc/ssh` exists in minimal Docker images. | Low — CI pipeline now reaches converge step; role content fixes are straightforward. | Add `openssh-server` to Docker images or guard SSH tasks with `when: ansible_os_family != 'Debian' or /etc/ssh exists`. | Principal |
| DEV-05 | ~~Critical~~ | infra | ~~5/10 Ansible roles declare unresolvable defaults (B16)~~ | ✅ Fixed: 30 self-referential defaults rewritten as plain literals across postgresql, minio, vault, nginx, wireguard. | Was critical. | ✅ Fixed in PR #26 commit 3025d7f. | — |
| DEV-06 | Medium | infra | Terraform google provider bump blocked (PR #23) | PR bumps staging root to `~> 8.1` but child modules (state-bucket, networking, gke) still constrain `< 7.0`. | Staging and production google provider versions diverge. No live state affected (GCP resources commented out). | Coordinated bump: update `versions.tf` in all 3 modules + lock files in one PR. | Principal |
| DEV-07 | Medium | jolarca | `trivy` + `dependency-audit` fail on main; block Dependabot PRs | Pre-existing vulnerabilities on main cause security checks to fail. The dependency bumps ARE the fix, but the checks block the merge. | Catch-22: can't merge the cure because the symptom blocks it. Worked around by temporarily removing contexts. | Fix root-cause vulnerabilities or adjust branch protection to allow admin bypass of security checks. | Principal |
| DEV-08 | Low | .github | Reusable `security-scan.yml` had fabricated gitleaks-action SHA | SHA `4f9a10a3b6e...` did not exist in the gitleaks-action repo. Replaced with real SHA `e6dab24...`. | Was dormant (no repo calls the reusable workflow). Would have failed if invoked. | ✅ Fixed in .github PR #1 (merged 2026-09-17). | — |
| DEV-09 | Medium | jolarca, compliance, .github | GitHub Actions not SHA-pinned (~40 unpinned `uses:` refs) | jolarca and jolarca-compliance use tag-only refs (`@v7`, `@master`). .github reusable workflows partially unpinned. | Supply-chain risk: a compromised upstream action could execute arbitrary code in CI. | ✅ P0 `@master` refs fixed (jolarca PR #92, .github PR #2). P2 tag-only refs remain in jolarca CI + all compliance workflows. | Principal |
| DEV-10 | Low | infra | Staging environment unprovisioned | All `ansible_host` lines in staging/hosts.yml commented out awaiting Proxmox hardware delivery. | No staging validation possible. All playbooks are source-only. | Close when Proxmox hardware arrives and VMs/LXCs are provisioned. | Principal |

---

## Resolved Deviations

| ID | Resolved | Resolution |
|----|----------|------------|
| DEV-08 | 2026-09-17 | Fabricated SHA replaced with real `e6dab24...` in .github PR #1 |
| DEV-09 (P0) | 2026-09-17 | All 7 `@master` refs pinned to SHA (jolarca PR #92, .github PR #2) |
| DEV-04 | 2026-09-17 | Molecule working-directory fixed + monitoring/redis requirements-file added (PR #26 ded2e22). Pending first green CI run. |
| DEV-05 | 2026-09-17 | 30 self-referential defaults rewritten as plain literals (PR #26 3025d7f). |

---

## Review Cadence

This register is reviewed:
- At every deployment gate assessment
- When a new deviation is discovered during audit
- Quarterly (minimum)
