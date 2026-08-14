# Runbook: PostgreSQL failover

**Status: skeleton — lands with the ansible `20-postgresql.yml` workstream.**
Decision gate: failover only when primary is confirmed unrecoverable within
RTO budget (≤ 4h) or data-plane loss is already user-visible. Failover is a
data-loss-risk event — RPO ≤ 15min is the promise, verify before you cut.

## Steps

1. [ ] Confirm primary truly down (not network partition — a partition with
   two writable primaries = split-brain = data corruption).
2. [ ] Check replication lag on the best replica (`pg_stat_wal_receiver`,
   last applied LSN). If lag > 15min, document expected data loss BEFORE
   promoting.
3. [ ] Fencing: ensure old primary CANNOT rejoin while split-brained
   (nftables block + stop service).
4. [ ] Promote chosen replica (`pg_ctl promote` / patroni-style failover,
   as implemented by the workstream).
5. [ ] Repoint application connection targets (DNS/service record).
6. [ ] Verify writes land; verify PITR/WAL archiving resumed.
7. [ ] Demote/repair old primary; resync as replica — never re-promote
   without full timeline reconciliation.

## Verification checklist

- [ ] Application transactions succeeding end-to-end
- [ ] Replication re-established (new replica count = expected)
- [ ] Backup chain (borg + WAL) continuous from failover point
- [ ] Monitoring alerts cleared; failover logged below + incident record

## Log

| Date | Old primary | Promoted replica | Data loss observed | Duration | Operator |
|------|-------------|------------------|--------------------|----------|----------|
| —    | —           | —                | —                  | —        | —        |
