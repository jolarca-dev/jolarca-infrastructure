# Security Policy — jolarca-infrastructure

## Scope

This is a **private infrastructure repository**. Vulnerabilities reported
here concern the infrastructure plane itself: IaC defects, secret handling,
state custody, CI/CD pipeline integrity, and the bare-metal/GKE topology
this repository describes.

## Reporting

**NEVER open issues about infrastructure vulnerabilities in public
repositories** (including `jolarca`). Infrastructure findings
stay inside the moat.

| Channel                    | Use for                                          |
|----------------------------|--------------------------------------------------|
| Private security advisory  | Vulnerabilities in this IaC or its pipeline      |
| Org security mailbox       | Suspected secret exposure, state leak, drift     |
| Break-glass procedure      | Active incident only — `docs/runbooks/`          |

Include: affected path(s), reproduction steps or plan/state excerpt
(**redact tokens and keys**), suspected blast radius.

## Response targets

| Stage                    | Target        |
|--------------------------|---------------|
| Acknowledgement          | 1 business day |
| Triage + severity        | 3 business days |
| Fix or mitigation (high) | 7 calendar days |

## What we treat as a security incident

- Any Terraform state file appearing outside its custody location.
- Any secret (token, key, vault password) in git history, logs, or artifacts.
- Any drift detected by `drift-detection.yml` that cannot be explained by
  an authorized change record.

Incident playbooks: `docs/runbooks/state-compromise.md`,
`docs/runbooks/github-token-rotation.md`.

## Supported scope

Only the default branch (`main`) of this repository is supported.
Workstream scaffolding marked *reserved* carries no security guarantees
until its workstream lands.
