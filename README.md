# Rockingham Homelab

Configuration for the Rockingham Homelab: a 6-node bare-metal Kubernetes
cluster (`rockingham`) running Talos Linux.

**Start here: [`ARCHITECTURE.md`](./ARCHITECTURE.md)** — what runs, where
it is configured, how changes reach the cluster, and how to verify them.
It owns the structure; values live in their owning files, vocabulary in
[`CONTEXT.md`](./CONTEXT.md), and decisions in
[`docs/adr/`](./docs/adr/).

- [`terraform/gcp/`](./terraform/gcp) — the GCP-side skeleton: project,
  tfstate bucket, the `talos-cluster-secrets` GSM container, and the CI
  identity.
- [`terraform/bootstrap/`](./terraform/bootstrap) — the cluster floor,
  applied from a workstation.
- [`talos/`](./talos) — per-node machine-config patches and the bring-up
  runbook.
- [`justfile`](./justfile) — `just smoke` runs a `cilium connectivity
  test` against the current kubeconfig (requires `just`, `cilium-cli`,
  and `kubectl` on `PATH`).

## Documentation

- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — the live-system map; read it
  first.
- [`CONTEXT.md`](./CONTEXT.md) — the canonical glossary used across this
  repo's PRs, ADRs, code, and chat.
- [`docs/adr/`](./docs/adr/README.md) — the load-bearing decisions, with
  an index marking what is in force and what is history.
