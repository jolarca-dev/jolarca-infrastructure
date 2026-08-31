# Runbook: Terraform state compromise

**Status: skeleton — fully executable once remote state (ADR-0003) lands.**
Trigger: state observed outside custody, or suspicion thereof.
A state leak is ALWAYS an incident (`../../SECURITY.md`). Do not wait for
certainty — containment first, forensics second.

## Immediate containment (first hour)

1. Freeze writes: disable `terraform.yml` apply (environment protection)
   and announce freeze.
2. [ ] Rotate every credential that appears in the leaked state
   (GitHub PATs first — `github-token-rotation.md`).
3. [ ] Revoke/rotate the CMEK key version: leaked copies become unreadable
   (`../../security/key-custody.md`).
4. [ ] Preserve evidence: copy bucket audit logs BEFORE changing anything
   further; store in `jolarca-compliance` evidence area.

## Assessment

5. [ ] Determine content scope of the leaked copy (which environment, age).
6. [ ] List resources in scope; classify data exposure (GDPR Art. 33/34
   assessment if personal-data-adjacent metadata involved; 72h clock).
7. [ ] Check drift: did the attacker also WRITE? (`scripts/check-drift.sh`)

## Recovery

8. [ ] Decide: re-key in place vs rebuild state from fresh apply
   (rebuild if write-compromise is confirmed).
9. [ ] Restore known-good state version if drift found
   (`../../backup/terraform-state/README.md`).
10. [ ] Re-enable apply only after two-person sign-off recorded.

## Post-incident (within 5 business days)

11. [ ] Blameless postmortem → ADR or policy change if structural.
12. [ ] Update `../threat-model.md` residual ratings.
13. [ ] File evidence bundle in `jolarca-compliance`.

## Log

| Date | Incident lead | Scope | Actions taken | Closed by |
|------|---------------|-------|---------------|-----------|
| —    | —             | —     | —             | —         |
