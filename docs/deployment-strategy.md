---
text: deployment-strategy
version: 1.0.0
status: approved
---

# Deployment Strategy: Blue-Green & Canary Readiness

**Purpose:** Document how production deployments will roll out safely.
**Status:** Planning — not yet implemented. This is the blueprint.

---

## Current State (Staging)

Staging uses a **single-environment deploy-and-rollback** strategy:
- Deploy to the single staging environment
- If broken, roll back via `git checkout` + rebuild
- Rollback test script: `scripts/rollback-test.sh`

This is acceptable for staging (low traffic, fast iteration) but
**insufficient for production** (real users, SLA commitments).

---

## Production Deployment Strategy

### Option A: Blue-Green Deployment (Recommended for Jolarca)

#### Architecture

```
                    ┌─────────────────┐
                    │   nginx edge    │
                    │  (load balancer)│
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────▼─────┐ ┌─────▼─────┐        │
        │  Blue     │ │  Green    │        │
        │  (active) │ │ (standby) │        │
        │  v1.2.3   │ │  v1.2.4   │        │
        │  :8000    │ │  :8001    │        │
        └───────────┘ └───────────┘        │
              │              │              │
              └──────┬───────┘              │
                     │                      │
              ┌──────▼──────┐               │
              │  PostgreSQL │               │
              │  (shared)   │               │
              └─────────────┘               │
```

#### How it works

1. **Blue** is the current production environment (serving traffic)
2. **Green** is the new version (deployed, tested, not serving traffic)
3. When Green passes health checks, switch nginx upstream from Blue → Green
4. If Green has issues, switch back to Blue (instant rollback)

#### Implementation plan

```yaml
# nginx upstream with blue-green switching
upstream django_backend {
    # Active version (controlled by Ansible variable)
    server 10.10.1.2:8000;  # Blue
    
    # Standby version (commented out until ready)
    # server 10.10.1.2:8001;  # Green
}
```

```bash
# Deploy to Green
ansible-playbook playbooks/65-app.yml \
  -i inventories/production/hosts.yml \
  --extra-vars "app_port=8001 app_version=v1.2.4"

# Test Green
curl -s https://10.10.1.2:8001/health

# Switch traffic to Green
ansible-playbook playbooks/70-nginx-edge.yml \
  -i inventories/production/hosts.yml \
  --extra-vars "backend_upstream=http://10.10.1.2:8001"

# If Green fails, switch back to Blue
ansible-playbook playbooks/70-nginx-edge.yml \
  -i inventories/production/hosts.yml \
  --extra-vars "backend_upstream=http://10.10.1.2:8000"
```

#### Pros
- Instant rollback (just switch upstream)
- Zero downtime (both environments running)
- Easy to test new version before switching

#### Cons
- Requires 2x infrastructure (2x app hosts, 2x ports)
- Database migrations must be backward-compatible
- More complex deployment scripts

---

### Option B: Canary Deployment

#### Architecture

```
                    ┌─────────────────┐
                    │   nginx edge    │
                    │  (weighted LB)  │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────▼─────┐ ┌─────▼─────┐        │
        │  Stable   │ │  Canary   │        │
        │  (95%)    │ │  (5%)     │        │
        │  v1.2.3   │ │  v1.2.4   │        │
        │  :8000    │ │  :8002    │        │
        └───────────┘ └───────────┘        │
              │              │              │
              └──────┬───────┘              │
                     │                      │
              ┌──────▼──────┐               │
              │  PostgreSQL │               │
              │  (shared)   │               │
              └─────────────┘               │
```

#### How it works

1. **Stable** serves 95% of traffic (current production)
2. **Canary** serves 5% of traffic (new version)
3. Monitor canary for errors, latency, business metrics
4. If canary is healthy, gradually increase traffic (5% → 25% → 50% → 100%)
5. If canary has issues, route 100% back to stable

#### Implementation plan

```nginx
# nginx weighted upstream
upstream django_backend {
    server 10.10.1.2:8000 weight=95;  # Stable
    server 10.10.1.2:8002 weight=5;   # Canary
}
```

```bash
# Deploy canary
ansible-playbook playbooks/65-app.yml \
  -i inventories/production/hosts.yml \
  --extra-vars "app_port=8002 app_version=v1.2.4"

# Monitor canary
curl -s https://10.10.1.2:8002/health
# Check error rates, latency, business metrics

# If healthy, increase canary weight
# (requires nginx config update + reload)

# If unhealthy, remove canary from upstream
# (requires nginx config update + reload)
```

#### Pros
- Gradual rollout (less risk)
- Real-world testing with small user subset
- Can test database migrations safely

#### Cons
- More complex monitoring required
- Need metrics pipeline (Prometheus, Grafana)
- Database migrations must be backward-compatible
- Requires traffic splitting logic

---

## Recommendation for Jolarca

**Start with Blue-Green for production.**

Rationale:
1. **Simpler to implement** — just switch nginx upstream
2. **Instant rollback** — critical for marketplace (users placing orders)
3. **Easier to test** — can verify Green before switching traffic
4. **No complex monitoring required** — just health checks

Canary can be added later when:
- Traffic volume justifies gradual rollout
- Monitoring pipeline is in place (Prometheus + Grafana)
- Team has experience with blue-green deployments

---

## Prerequisites for Production Deployment

Before implementing blue-green or canary:

| Requirement | Status | Notes |
|-------------|--------|-------|
| 2x app hosts | ❌ Not yet | Need second VM or container |
| Database migration backward compatibility | ❌ Not yet | Must design migrations carefully |
| Automated health checks | ✅ Done | `/api/v1/health/` endpoint exists |
| Monitoring pipeline | ❌ Not yet | Need Prometheus + Grafana |
| Deployment scripts | ❌ Not yet | Need blue-green deployment script |
| Rollback automation | ✅ Done | `rollback-test.sh` exists |
| Feature flags | ❌ Not yet | For gradual feature rollout |

---

## Migration Strategy

### Backward-compatible migrations (required for blue-green)

```python
# ✅ GOOD: Add column, then populate in background
class Migration:
    def forwards(self):
        # Step 1: Add nullable column
        schema.add_column('products', 'new_field', models.CharField(null=True))
        
        # Step 2: Populate in background (data migration)
        # Run separately after deploy
        
        # Step 3: Make non-nullable (next deploy)
        # schema.alter_column('products', 'new_field', null=False)

# ❌ BAD: Rename column (breaks old code)
class Migration:
    def forwards(self):
        schema.rename_column('products', 'old_field', 'new_field')
```

### Migration checklist

- [ ] New columns are nullable or have defaults
- [ ] No column renames (use add + deprecate old)
- [ ] No column drops (wait 2 deploys)
- [ ] Indexes created before queries use them
- [ ] Data migrations run in background (not in deploy)
- [ ] Rollback migration tested

---

## Deployment Checklist (Production)

Before every production deployment:

- [ ] Staging deployment successful
- [ ] Rollback test passed (`./scripts/rollback-test.sh`)
- [ ] Database migrations are backward-compatible
- [ ] Pre-deploy backup exists
- [ ] On-call operator identified
- [ ] Monitoring alerts configured
- [ ] Feature flags ready (if applicable)
- [ ] Rollback plan reviewed
