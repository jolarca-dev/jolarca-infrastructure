# monitoring/ — observability as code — RESERVED

Workstream **pending**. Layout reserved:

```text
prometheus/            # scrape configs (GKE + bare metal over WireGuard), recording rules
alertmanager/          # routes: page on-call for data-plane down; ticket for drift
grafana/dashboards/    # RED metrics, PG replication lag, borg job status, WG handshake age
alerts/                # alert rules as code
```

## Planned alert rules (must exist before production cutover)

| Alert                  | Severity | Why                                      |
|------------------------|----------|------------------------------------------|
| PG replication lag     | page     | RPO ≤ 15min target (restore-drill.md)    |
| Backup age > 25h       | page     | daily borg cadence broken                |
| Certificate expiry <14d| ticket   | edge TLS lapse = outage                  |
| Terraform drift        | ticket   | drift-detection.yml opened an issue      |
| WG handshake age > 10m | page     | the only bridge between planes is down   |

Alert rules are code-reviewed like IaC: they encode our RTO/RPO promises.
