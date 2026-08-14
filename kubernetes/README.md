# kubernetes/ — workloads on the 10% GCP plane — RESERVED

Workstream **pending**. Lands with the GKE module (`terraform/modules/gke`).

## Planned layout

```text
helm/          # jol-api, jol-celery, jol-llm-inference, jol-ingress charts
base/          # Kustomize bases: namespace, default-deny NetworkPolicy
overlays/{staging,production}/
policies/      # Kyverno/Gatekeeper admission policies
```

## Non-negotiables when implemented

- No `:latest` image tags; digests preferred (supply chain, CC7.1)
- No privileged pods; non-root `securityContext`, read-only rootfs
- Liveness/readiness probes required on every workload
- Default-deny NetworkPolicy per namespace; explicit allows only
- HPA + PDB on every user-facing deployment
- Admission policies reviewed by `@journeyoflife-org/security` (CODEOWNERS)

Do not commit manifests until the workstream change request is approved.
