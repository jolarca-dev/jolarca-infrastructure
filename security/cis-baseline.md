# CIS baseline — host hardening standard & exceptions register

**Standard:** CIS Ubuntu Linux 22.04/24.04 LTS Benchmark (Level 1 as floor,
Level 2 where operationally viable). Applied by
`ansible/playbooks/00-hardening.yml` at first boot and enforced
continuously (drift is a finding, not a to-do).

## Mandatory floor (no exceptions without CISO sign-off)

- SSH: key-only, no root login, no password auth, MFA at bastion
- nftables default-deny inbound (security/network-policy.md)
- fail2ban on SSH and edge listeners
- unattended-upgrades for security patches (auto, unattended)
- auditd with tamper-evident shipping to the compliance log sink
- No world-writable files; umask 027; core dumps disabled
- Time sync (chrony) to redundant sources — logs are evidence only with
  trustworthy clocks (ISO 27001 A.8.17)

## Verification

- `00-hardening.yml` is idempotent and converging runs are asserted in
  `99-verify.yml` and molecule tests.
- Quarterly audit compares running config against this baseline; gaps
  become exceptions below or fixes.

## Exceptions register

Each exception states control, reason, compensating control, owner, and
expiry. Expired exceptions are violations.

| ID | Control | Deviation | Reason | Compensating control | Owner | Granted | Expires |
|----|---------|-----------|--------|----------------------|-------|---------|---------|
| —  | —       | —         | —      | —                    | —     | —       | —       |

_No exceptions currently granted._
