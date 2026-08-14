# Runbook: WireGuard key rotation

**Status: skeleton — lands with the ansible `10-wireguard.yml` workstream.**
The mesh is the ONLY bridge between planes (`../../security/isolation-model.md`
boundary 2); its keys couple everything. Rotate: annually, on host
decommission, on personnel change with host access, or on suspicion.

## Principles

- Private keys are generated host-side and NEVER leave the host (not into
  git, not into vault files, not into chat). Only public keys are
  collected into the mesh configuration.
- Rotate one peer at a time (rolling), keeping the mesh up — never a
  mass rekey unless responding to a confirmed compromise.

## Steps (per peer)

1. [ ] Generate new keypair ON the peer host.
2. [ ] Distribute the new PUBLIC key through the mesh config (ansible,
   reviewed PR — the config change itself is change-managed).
3. [ ] Apply on neighbors; verify handshake re-establishs.
4. [ ] Remove the old public key from ALL peers (a leftover old key is an
   unfinished rotation).
5. [ ] Confirm zero traffic on the old key, then shred the old private key
   on the host.
6. [ ] Verify cross-plane flows (metal→GKE and back) — the bridge is the
   canary.

## Mass-rekey (compromise response only)

Treat as incident (`../../SECURITY.md`): assume the mesh is observed;
rotate all peers in one window with two operators, then audit peer
allow-lists against `../../security/network-policy.md`.

## Log

| Date | Peer(s) rotated | Reason | Old keys removed | Verified |
|------|-----------------|--------|------------------|----------|
| —    | —               | —      | —                | —        |
