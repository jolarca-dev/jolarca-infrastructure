# Runbook: GitHub token rotation

**Status: ACTIVE** — the GitHub PAT is the current live credential plane for
`terraform/modules/github-org`. Rotate every 90 days, on personnel change,
or on any suspicion of exposure. Basis: SOC 2 CC6.1, ISO 27001 A.5.17.

## Preconditions

- You are a named custodian in `../../security/key-custody.md`.
- A replacement token already generated (fine-grained PAT, scope strictly
  `repo` + `read:org` — see module `versions.tf` least-privilege note).
- Announce the window in the operator channel (rotation = audited event).

## Steps

1. Generate new PAT in GitHub (shortest viable expiry: 90d).
2. Update org secret `TF_GITHUB_TOKEN_READONLY` (used by PR plan + drift).
3. Update environment secret `TF_GITHUB_TOKEN_WRITE` on the `production`
   environment (used by gated apply).
4. Verify read path: `scripts/check-drift.sh production` exits 0.
5. Verify write path WITHOUT applying: run a PR plan through
   `terraform.yml` and confirm it completes.
6. **Revoke the old token.** Unrevoked old tokens defeat the rotation.
7. Record: CHANGELOG.md entry + `../../security/access-review.md` note +
   compliance evidence repo entry (date, operator, reason).

## Verification

- `drift-detection.yml` next run passes with the new token.
- No workflow references the old token (GitHub shows zero usage after 24h).

## If the token is suspected compromised

Skip the window: revoke FIRST, then rotate, then treat as incident
(`../../SECURITY.md`) and review recent workflow/apply history for
unauthorized changes.

## Log (append-only)

| Date | Operator | Reason | Old token revoked | Verified |
|------|----------|--------|-------------------|----------|
| —    | —        | —      | —                 | —        |
