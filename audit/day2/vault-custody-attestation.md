# Vault Custody Attestation

**Date:** [YYYY-MM-DD]
**Vault cluster:** [staging/production]
**Initialization parameters:**
- Key shares: 3
- Key threshold: 2
- Root token: generated, used once for setup, then REVOKED

---

## Custodians

Each custodian received one unseal share, sealed offline (paper in
envelope or hardware token). No share was pasted into chat, committed
to any repository, or stored on any VM.

| Custodian # | Name | Role | Share received | Storage method |
|-------------|------|------|---------------|----------------|
| 1 | [name] | [role] | Share 1 | [envelope / hardware token] |
| 2 | [name] | [role] | Share 2 | [envelope / hardware token] |
| 3 | [name] | [role] | Share 3 | [envelope / hardware token] |

---

## Root Token Revocation

The root token was used once to:
1. Enable KV-v2 at `secret/`
2. Enable audit device
3. Create initial policies
4. Create initial AppRoles

After setup, the root token was revoked:

```
vault token revoke <root-token>
```

**Revocation confirmed:** [ ] YES
**Date revoked:** [YYYY-MM-DD]
**Confirmed by:** [name]

---

## Day-to-Day Authentication

- **Applications (vm-app, vm-backup):** AppRole auth
- **Break-glass:** userpass for emergency access
- **Operators:** OIDC/LDAP (when configured)
- **CI pipelines:** short-lived AppRole tokens

---

## Attestation

We attest that:
1. Each custodian received exactly one unseal share
2. No share was transmitted electronically
3. The root token was used once and revoked
4. All initial configuration was performed via the root token before revocation

**Custodian 1 signature:** _______________ **Date:** _______
**Custodian 2 signature:** _______________ **Date:** _______
**Custodian 3 signature:** _______________ **Date:** _______
**Operator signature:** _______________ **Date:** _______
