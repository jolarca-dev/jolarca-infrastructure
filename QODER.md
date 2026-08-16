# QODER.md

Behavioral guidelines to reduce common LLM coding mistakes when using Qoder in PyCharm. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.
- Prefer PyCharm's built-in refactoring tools (Rename, Extract Method, Move, etc.) over manual text manipulation when the IDE can do it safely.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

## Project-Specific Guidelines — jol-m-infrastructure

This repository changes production infrastructure; every merge is a
change-management record (SOC 2 CC8.1, ISO 27001 A.8.32). The full rules live
in `CONTRIBUTING.md`; these constrain AI-assisted changes:

### Workflow: plan-first

1. **Issue first.** Infrastructure changes require a change request
   (`change_request.yml`) stating risk class, blast radius, and rollback plan.
   Changes without these three fields are closed.
2. **Plan before apply.** Terraform changes ship with `terraform plan` output
   attached to the PR. Never generate or suggest `terraform apply`; no
   "apply-first, plan-later".
3. **Small, reviewable diffs.** One concern per PR.
4. **CI is a merge gate.** `ci`, `security`, and terraform checks must be
   green; branch protection enforces this including for administrators.

### Change-risk classes

| Class | Examples                                        | Gate                          |
|-------|-------------------------------------------------|-------------------------------|
| Low   | Docs, comments, reserved scaffolding            | 1 review                      |
| Med   | Non-prod resource changes, module refactors     | 1 review + plan attached      |
| High  | Prod resources, IAM, network, state custody     | 2-person rule + rollback plan |
| Crit  | State migration, secret rotation, destroy paths | 2-person rule + change window |

State the risk class for every infrastructure change.

### The two-person rule

Security-sensitive paths (non-exhaustive): `terraform/backends/`,
`terraform/policies/`, `ansible/vault/`, `security/`, `scripts/`,
`.github/workflows/`, `kubernetes/policies/`.

- Changes here require review beyond the author; the author never self-approves.
- Flag the risk class explicitly; never bundle these edits with unrelated changes.
- Solo-era operation: enforcement rides on the automated gates (required
  `ci` + `security` checks, plan-first workflow, daily drift detection) — a
  tracked deviation (`security/key-custody.md`), not an exemption.

### Secrets — never in git

- No tokens, keys, PEMs, vault password files, or `.tfstate` — enforced by
  `.gitignore`, pre-commit (gitleaks), and `scripts/audit-no-secrets.sh`.
- Never print or echo state file contents — state contains secrets.
- Never suggest bypassing pre-commit (`--no-verify`); run
  `make fmt lint check` before commit.
- Runtime credentials come from the operator environment or Vaultwarden;
  Ansible secrets are `ansible-vault` encrypted with per-environment
  passwords under dual control.

### Policy gates

- Terraform changes must pass the OPA policies (`no-public-ips`,
  `no-basic-iam-roles`, `require-cmek`), tflint, and checkov before being
  proposed as complete.

### Rollback

Every PR must state how to revert it. For Terraform: the inverse plan or
restored state version. If you cannot describe the rollback, the change is
not ready.
