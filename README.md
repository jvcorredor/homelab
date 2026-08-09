# Rockingham Homelab

Configuration for the Rockingham Homelab: a 6-node bare-metal Kubernetes
cluster (`rockingham`) running Talos Linux.

The cluster runs the **barebones floor** (see ADR-0009, the 2026-08-09
reset): Talos + Kubernetes + Cilium + Gateway API CRDs + local-path
storage + metrics-server. There is no GitOps, DNS, TLS, or secrets
management layer — those existed, were never understood by the operator,
and were backed out. New layers are added by hand as learning exercises.

- [`terraform/gcp/`](./terraform/gcp) — the GCP-side skeleton: the
  project, the GCS state bucket, the `talos-cluster-secrets` GSM
  container, and the CI plan/apply service accounts with their GitHub
  OIDC Workload Identity pool.
- [`terraform/bootstrap/`](./terraform/bootstrap) — cluster bootstrap, in
  order: Gateway API CRDs → Cilium (CNI + kube-proxy replacement + LB
  IPAM + Gateway API) → local-path-provisioner → metrics-server.
- [`talos/`](./talos) — per-node Talos machine-config patches and the
  bring-up runbook for the cluster.
- [`justfile`](./justfile) — `just smoke` runs a `cilium connectivity
  test` against the current kubeconfig. Requires `just`, `cilium-cli`,
  and `kubectl` on `PATH`.

## Documentation

[`CONTEXT.md`](./CONTEXT.md) is the canonical glossary used across this
repo's PRs, ADRs, code, and chat. Read it once before working in this
repo so terms aren't re-derived each time.

[`docs/adr/`](./docs/adr) records the load-bearing decisions — including
the superseded ones, which document what the removed layers were for.
ADR-0009 (the barebones reset) is the current frame; ADR-0002 (Cilium)
and ADR-0004 (CI-driven apply) remain in force.
