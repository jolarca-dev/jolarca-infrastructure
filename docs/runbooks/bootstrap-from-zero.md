# Runbook: bootstrap from zero

**Status: skeleton — completes as each workstream lands.** The ordered path
from a new operator's laptop to a fully converged environment. Every step
names its artifact so the procedure is testable, not tribal.

## Order

1. **Access grants** — repo access, Vaultwarden entry, team membership;
   recorded in `../../security/access-review.md`.
2. **Toolchain** — terraform (pinned version per
   `.github/actions/terraform-setup`), pre-commit, ansible (when live).
3. **Environment** — `cp .envrc.example .envrc`; obtain credentials from
   Vaultwarden per `../../security/key-custody.md`. NEVER receive secrets
   via chat/email.
4. **Local gates** — `make fmt lint check` green on a fresh clone.
5. **Read-only proof** — `scripts/check-drift.sh production` exits 0.
6. **First supervised change** — a Low-class docs/comment PR through the
   full flow (issue → PR → CI → review).
7. **Plane-specific steps** (land with workstreams):
   - [ ] Terraform: state bootstrap rehearsal (`../../terraform/README.md`)
   - [ ] Ansible: vault decrypt dry-run against staging inventory
   - [ ] K8s: kubectl context via Workload Identity only
8. **DR familiarity** — read `../../backup/restore-drill.md` + one runbook
   of choice, summarized back to the onboarding buddy (two-person rule
   requires both holders actually know the procedures).

## Completion criterion

Operator can independently run steps 4–6 and explain the moat doctrine
(`../../security/isolation-model.md`). Sign-off recorded in the access
review log.
