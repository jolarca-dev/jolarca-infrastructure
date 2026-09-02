# ADR-0006: Redis Placement — Co-located on App Host

**Status:** Accepted
**Date:** 2026-09-02
**Deciders:** Infrastructure Lead, Backend Lead

## Context

The Jolarca marketplace requires Redis for:
1. Celery task broker (async job queue)
2. Django cache backend (session cache, rate-limit counters)

The question: should Redis run on a dedicated VM, or co-located on the app host?

## Decision

**Redis runs on the app host (10.10.1.2), bound to the WireGuard interface only.**

## Rationale

### Arguments for co-location (CHOSEN)

1. **Simplicity**: One fewer VM to provision, patch, monitor, and back up.
2. **Latency**: App-to-Redis is localhost-only (no WireGuard hop for cache/broker traffic).
3. **Cost**: Redis memory footprint is small (256MB maxmemory). Dedicated VM would be wasteful.
4. **Failure domain**: If the app host fails, both app and cache die together — but the app is unusable without Redis anyway (Celery broker, session store). No partial failure mode.
5. **Security**: Redis binds to WireGuard IP only. No external exposure. Password from Vault.

### Arguments against co-location (REJECTED)

1. **Resource contention**: Redis and Django compete for CPU/memory. Mitigated by cgroups/systemd resource limits and 256MB maxmemory cap.
2. **Scaling**: Can't scale Redis independently. Not needed at staging/early-production scale. Revisit if Redis becomes a bottleneck.
3. **Blast radius**: App host failure kills both. Accepted — app is unusable without Redis.

## Consequences

### Positive
- Simpler infrastructure (7 VMs, not 8)
- Lower latency for Celery tasks and cache reads
- Lower cost (no dedicated Redis VM)

### Negative
- Redis and app share failure domain (accepted — no partial failure mode)
- Cannot scale Redis independently (revisit at scale)

### Neutral
- Redis data lives on app host disk (AOF everysec for broker reliability)
- Redis password sourced from Vault like all other secrets

## Implementation

- Redis role: `ansible/roles/redis/`
- Redis playbook: `ansible/playbooks/45-redis.yml`
- Bind address: `10.10.1.2` (WireGuard IP of app host)
- Max memory: 256MB, allkeys-lru eviction
- Persistence: AOF everysec (acceptable for Celery broker)
- Security: requirepass from Vault, dangerous commands disabled

## Review

Revisit if:
- Redis memory usage consistently exceeds 200MB
- Celery task latency becomes a bottleneck
- Production scale requires dedicated cache tier
