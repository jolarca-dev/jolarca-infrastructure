# Access review — quarterly template & log

**Cadence:** quarterly. **Evidence destination:** `jolarca-compliance`.
**Standards:** SOC 2 CC6.1 (periodic review of logical access), ISO 27001
A.5.18 (access rights review), PCI-DSS 7.2.5 / 12.5.2.

## Review checklist (repeat each quarter)

1. **Humans**
   - [ ] Every repo collaborator/team membership still has a business need
   - [ ] No account with access remains for departed personnel
   - [ ] Two-person-rule roles have ≥2 active holders (no single points)
2. **Machines**
   - [ ] Every service account/PAT in `key-custody.md` exists in reality,
         and every credential in reality appears in the register
   - [ ] No credential past its rotation date; overdue = rotation NOW
   - [ ] GCP IAM bindings contain no basic roles (OPA-enforced, verified)
3. **Network**
   - [ ] Every allow row in `network-policy.md` still has a live purpose
   - [ ] No connected-to-CDE system appeared outside `pci-dss-scope.md`
4. **State & secrets**
   - [ ] State buckets contain only state; versioning + CMEK intact
   - [ ] gitleaks nightly scan green for the whole quarter

Findings get issues; findings touching production get change requests.

## Review log (append-only)

| Quarter    | Reviewer 1 | Reviewer 2 | Findings | Remediation |
|------------|------------|------------|----------|-------------|
| _pending_  | —          | —          | —        | —           |

Rows are append-only evidence. Corrections are new rows referencing the
original — never edits to past rows.
