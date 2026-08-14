# Threat model — infrastructure plane (STRIDE)

Scope: the control plane described by this repository (state, pipelines,
bridge, secrets), NOT application-level threats of jol-m-marketplace.
Review cadence: annually + on any architecture ADR.

## Crown jewels (ranked)

1. Production Terraform state (full topology + config metadata)
2. ansible-vault production secrets + Vault unseal keys
3. CI write credentials (GitHub PAT write, GCP apply SA)
4. The WireGuard mesh (the only bridge — compromising it couples the planes)

## STRIDE register

| Threat | Category | Asset | Scenario | Mitigation in this repo | Residual |
|--------|----------|-------|----------|--------------------------|----------|
| State file exfiltration | Information disclosure | #1 | Leaked laptop/CI artifact copy | GCS-only custody, CMEK revocability, `.gitignore`+gitleaks, state-compromise runbook | Low-Med |
| Forged apply | Tampering | #3 | Compromised PAT pushes malicious change | branch protection + 2-person rule + plan gate + drift detection | Low |
| Insider with dual keys | Elevation | #2 | Single person social-engineers both custodians | dual control with split custody, quarterly access review, rotation on personnel change | Med |
| WG peer compromise | Tampering/EoP | #4 | One compromised node pivots across the mesh | per-peer keys, default-deny beyond mesh port, key rotation runbook, peer allow-list per service | Med |
| Supply-chain hook poisoning | Tampering | pipelines | Malicious pre-commit/action rev | pinned revs + hashes, dependabot, CODEOWNERS on workflows | Low |
| CI secret leak in logs | Info disclosure | #3 | Terraform output echoes token | secrets masked, plan artifacts redacted, gitleaks on history | Low |
| State deletion/ransomware | Denial of service | #1 | Attacker with bucket write deletes versions | versioning + retention, independent backup layer, restore drill | Low |
| Drift as cover | Tampering | all | Out-of-band change hides malicious config | daily drift workflow + unexplained drift = incident | Low |

## Standing assumptions to re-verify

- The GitHub provider token scopes remain minimal (`repo` + `read:org`).
- No new bridge route exists besides WireGuard (isolation-model boundary 2).
- Break-glass keys were rotated after their last use.

Each assumption failure is a finding for `../security/access-review.md`.
