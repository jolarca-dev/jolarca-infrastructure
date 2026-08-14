# Runbook: HashiCorp Vault sealed

**Status: skeleton — lands with the ansible `30-vault.yml` workstream.**
A sealed Vault stops secret issuance for the whole data plane. Speed
matters; quorum discipline matters more.

## Preconditions

- Unseal key holders: 3 of 5 required (custody:
  `../../security/key-custody.md`). No holder may act alone, ever.
- Key shares are retrieved from their OFFLINE locations — never from
  chat, email, or screenshots.

## Steps

1. [ ] Confirm seal state on all raft nodes (`vault status`).
2. [ ] Establish WHY it sealed (restart? new cluster? attack?). If
   unexplained → treat as incident FIRST (`../../SECURITY.md`).
3. [ ] Convene ≥3 key holders; each enters their share independently —
   no share is ever spoken, screenshared, or pasted.
4. [ ] Verify unseal progress on each node until active.
5. [ ] Confirm audit device re-enabled; re-enable any secret engines that
   stayed disabled.
6. [ ] Validate downstream consumers (app hosts retrieving secrets).
7. [ ] Log the event (time, holders present, reason) — append-only.

## Post-incident review triggers

- Sealed due to unauthorized restart → who/what triggered it?
- Any key holder unreachable → custody update + rekey consideration.

## Log

| Date | Reason | Key holders present | Duration | Follow-up |
|------|--------|---------------------|----------|-----------|
| —    | —      | —                   | —        | —         |
