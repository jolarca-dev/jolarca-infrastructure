---
text: restore-drill-log
version: 1.0.0
status: approved
---

# Restore Drill Log

**Targets:** RTO ≤ 4h, RPO ≤ 15min.
**Cadence:** Quarterly (ISO 27001 A.5.29 / A.5.30, SOC 2 A1.3).
**Automated drill script:** `scripts/restore-drill.sh`

## Drill Scope (each quarter)

1. **State restore:** Recover Terraform state from versioned GCS bucket
   into a scratch bucket; verify plan against live resources.
2. **Data restore:** Restore PostgreSQL PITR snapshot to a test database;
   verify RPO ≤ 15min.
3. **Offsite restore:** Pull one Borg archive from offsite provider;
   extract canary file; verify checksum.
4. **Full rebuild:** Rebuild one node from zero using Ansible playbooks
   + BorgBackup restore.

## Pass Criteria

- All four steps completed within 4h wall clock (RTO).
- PITR restore landed within 15min of the drill marker (RPO).
- Every anomaly filed as an issue in the repository.

## Drill Log

| Date | Lead | Scope | RTO | RPO | Borg archives verified | Offsite restored | Findings |
|------|------|-------|-----|-----|----------------------|-----------------|----------|
| _pending_ | — | — | — | — | — | — | First drill pending deployment of 80-backup.yml |

---

## Drill Procedure (step-by-step)

### Pre-drill

```bash
# Record the drill marker timestamp
echo "Drill marker: $(date -u +%Y-%m-%dT%H:%M:%SZ)" > /tmp/drill-marker.txt

# Verify backup is current
ssh deploy@10.10.1.7 "cat /var/backups/last-backup-status"
ssh deploy@10.10.1.7 "/usr/local/bin/backup-monitor.sh"
```

### Step 1: State Restore

```bash
# List state versions in GCS
gcloud storage objects list gs://jolm-tfstate-staging-3c4a45/terraform/staging/ --versions | head -5

# Download latest state to scratch location
gcloud storage cp gs://jolm-tfstate-staging-3c4a45/terraform/staging/default.tfstate /tmp/scratch-state/

# Verify state is valid
terraform show /tmp/scratch-state/default.tfstate | head -20
```

### Step 2: Data Restore (PostgreSQL PITR)

```bash
# Find the most recent pg_dump
ssh deploy@10.10.1.7 "ls -lt /var/backups/postgresql/*.dump | head -3"

# Copy to DB host and restore
scp deploy@10.10.1.7:/var/backups/postgresql/jol_marketplace_LATEST.dump /tmp/
sudo -u postgres pg_restore -d jol_marketplace_test /tmp/jol_marketplace_LATEST.dump

# Verify RPO: check the most recent record timestamp
sudo -u postgres psql -d jol_marketplace_test -c "
  SELECT max(created_at) FROM products;
"
# Compare with drill marker — delta must be ≤ 15min
```

### Step 3: Offsite Restore

```bash
# List offsite archives
borg list borg@offsite-eu:./jolarca-staging

# Extract a canary file
mkdir -p /tmp/offsite-restore
cd /tmp/offsite-restore
borg extract borg@offsite-eu:./jolarca-staging::<latest-archive> --pattern 'var/backups/postgresql/*.dump'

# Verify the extracted dump is valid
pg_restore --list /tmp/offsite-restore/var/backups/postgresql/*.dump | head -10
```

### Step 4: Full Rebuild

```bash
# Run the automated restore drill
./scripts/restore-drill.sh /var/backups/borg-repo /tmp/restore-drill

# Record the results
echo "Drill completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> /tmp/drill-marker.txt
cat /tmp/drill-marker.txt
```

### Post-drill

1. Record results in the drill log table above.
2. File any anomalies as issues.
3. Clean up temporary files.
4. Notify the team of drill results.

---

## Historical Drill Results

_Entries are append-only evidence. Never edit past rows; correct with a
new row referencing the original._

### Drill #1 — [DATE PENDING]

- **Lead:** [name]
- **Scope executed:** [1/2/3/4]
- **RTO result:** [X]min (target: ≤ 240min)
- **RPO result:** [X]min (target: ≤ 15min)
- **Borg archives verified:** [X] archives, latest: [name]
- **Offsite restored:** [yes/no]
- **Findings:**
  - [list any anomalies or issues]
- **Corrective actions:**
  - [list any follow-up items]
