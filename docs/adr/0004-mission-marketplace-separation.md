# ADR-0004: Mission platform / marketplace separation (one org, two projects)

- **Status:** Accepted (operator directive, 2026-08-15)
- **Date:** 2026-08-15
- **Deciders:** org owner (solo era)

## Context

The `journeyoflife-org` GitHub organization hosts TWO distinct projects
that share nothing but the org shell:

| Project | Scope | Prefix | Local tree | Compliance scope |
|---|---|---|---|---|
| Journey of Life — Roman Catholic digital mission platform | pastoral/mission services | `jol-*` | `/opt/jol/repos/` | outside marketplace scope |
| Journey of Life — Marketplace | Baltic B2C/B2B commerce | `jol-m-*` (m = marketplace) | `/opt/jol-m/repos/` | PCI-DSS (Stripe), GDPR, KYC/AML, VAT OSS, SOC 2 / ISO 27001 evidence |

Mixing them is a compliance boundary violation, not a style preference:

- **GDPR purpose limitation (Art. 5(1)(b), Art. 32):** mission data
  (religious-context processing) and marketplace data
  (commercial/financial processing) are different processing purposes;
  shared tooling, tokens, or agent context creates unlawful scope bleed.
- **PCI-DSS scope control:** the marketplace carries card-payment scope;
  every person/token/repo with access to it expands the audit surface.
  Mission repos must stay OUT of that surface.
- **SOC 2 CC6.1:** logical access boundaries must be defined and
  enforced between distinct systems.

GitHub has no folder/group construct for repositories — "marketplace/"
naming is not available. Separation must therefore be conventional,
technical, and monitored.

## Decision — the rules (R1–R7)

- **R1 — Prefix covenant.** Marketplace repositories are `jol-m-*` and
  NOTHING else; mission repositories are `jol-*` (without `m`). No other
  prefix joins either fleet. The marketplace fleet is exactly:
  `jol-m-marketplace`, `jol-m-infrastructure`, `jol-m-compliance`,
  `jol-m-legal`, `jol-m-data`.
- **R2 — Terraform is the only creator.** Marketplace repos are created
  ONLY via `terraform/modules/github-org`. Out-of-band creation is an
  incident: import into state within 48h or delete the repo.
- **R3 — Enforced, not hoped for.**
  - module validation rejects non-`jol-m-*` fleet keys
    (`terraform/modules/github-org/variables.tf`);
  - `scripts/check-fleet-separation.sh` + the
    `fleet-separation-guard.yml` workflow fail when the org's `jol-m-*`
    set ≠ the fleet map (weekly + on change).
- **R4 — No cross-project access artifacts.** No shared repo/environment
  secrets across projects; marketplace workflows use repo-scoped
  secrets only (never org secrets); no CODEOWNERS, workflow, or module
  in one project references the other's repos.
- **R5 — Local and agent separation.** Distinct directory trees
  (`/opt/jol/repos` vs `/opt/jol-m/repos`); one project root per IDE
  window; agent memory/instructions must not span both projects.
- **R6 — Metadata marking.** Marketplace repos carry the `marketplace`
  topic; visibility/license policy lives in the fleet map
  (`jol-m-marketplace` public+AGPL-3.0 by doctrine, all others private).
- **R7 — Split triggers.** The shared org is re-evaluated — migrating
  marketplace to its own org — upon ANY of: a second operator joins;
  marketplace gains external contributors; PCI scope expands beyond the
  current boundary; billing must separate. A separate org is the only
  true hard boundary; until then R1–R6 are the compensating controls.

## Alternatives considered

- **Separate GitHub org now** (e.g. `jol-marketplace` org): strongest
  isolation (IAM, secrets, policies, billing) but doubles Team-plan
  cost and migration effort (remotes, CI tokens, WIF trust, TF org
  variable) for a solo operator. Deferred to the R7 triggers.
- **Repo "folders"/groups: not a GitHub feature.** Naming prefix +
  topics + teams are the available constructs; prefix is the only one
  that is grep-able, guard-able, and typo-proof.
- **Status quo (convention only):** already failed once — repos created
  out-of-band, protections missing, drift undocumented. Rejected.

## Consequences

- (+) Mission platform stays outside the PCI/marketplace audit surface.
- (+) Any marketplace repo drift becomes a failing CI check, not folklore.
- (−) Every new marketplace repo must go through Terraform (by design).
- (−) Org-level settings (secrets, webhooks, apps) remain shared and
  MUST be audited: org secrets must never be visible to marketplace
  workflows (token-scope gap: current CI token cannot list org secrets —
  audit in the org UI; tracked as R4 follow-up).

## Compliance mapping

GDPR Art. 5(1)(b)/Art. 32 (purpose limitation, security of processing);
PCI-DSS scope isolation; SOC 2 CC6.1 (logical access), CC8.1 (change
control — Terraform-only creation); ISO 27001 A.5.2/A.5.15 (governance
of information security, access control).
