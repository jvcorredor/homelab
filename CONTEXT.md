# CONTEXT

The canonical vocabulary used across this repo's PRs, ADRs, code, and chat.
If a term shows up in a commit message, an issue, or an agent session and
isn't self-evident, it should be defined here.

This file complements the ADRs under `docs/adr/`: ADRs explain **why** a
decision was made, CONTEXT explains **what we call things**.

> **2026-08-09 barebones reset (ADR-0009).** Everything above the floor —
> ArgoCD, cert-manager, ESO, Longhorn, Harbor, ARC, the Cloudflare preview
> surface, observability, split-horizon DNS — was backed out. The removed
> vocabulary lives in the superseded ADRs and git history, not here.
> Entries below are the live state.

## Cluster and naming

### `rockingham`

The Talos Kubernetes cluster's name. Used as the cluster identity in Talos
config, kubeconfig contexts. Not a hostname.

### `jackhall.dev`

The operator's domain, registered at Squarespace. Currently **lapsing**:
the lab used it for internal service DNS (`lab.jackhall.dev` on Cloud DNS,
apex on Cloudflare), and both providers were removed in the reset. The
registration itself is untouched. Nothing resolves; nothing needs to.

### `rockingham-homelab` (GCP project)

The single GCP project that owns the cloud-side skeleton: the tfstate GCS
bucket, the `talos-cluster-secrets` GSM container, and the CI service
accounts. Isolation is project-level so the homelab's blast radius is
bounded.

## Cluster contents (the floor)

The terms below name what runs on the cluster. For what is live, where
each piece is configured, and what was removed, see
[`ARCHITECTURE.md`](./ARCHITECTURE.md).

### Cilium (unified networking layer)

A single Helm release covering four roles: CNI, kube-proxy replacement,
LB IPAM + L2 announcements, and Gateway API. The only thing that touches
the data plane. See ADR-0002.

### LB pool

The range Cilium hands out to `Service`s of type `LoadBalancer` via
`CiliumLoadBalancerIPPool`, pinned in
[`terraform/bootstrap/variables.tf`](./terraform/bootstrap/variables.tf).
It sits above the Optimum DHCP scope and below the static cluster range.
No pins are currently load-bearing; the pre-2026-08 allocations (AdGuard,
the lab Gateway) are gone.

### Static cluster range

The static addresses for the six nodes and the shared control-plane VIP,
set per node under [`talos/patches/nodes/`](./talos/patches/nodes/). The
inventory table lives in [`talos/README.md`](./talos/README.md).

### Optimum DHCP scope (`192.168.1.11`–`192.168.1.199`)

The Optimum Gateway 6E hands out DHCP leases only in this range, leaving
`.200`–`.254` free for static cluster and LB-pool use.

## Storage

`local-path-provisioner` is the default and only `StorageClass`. PVCs bind
to a directory on whatever node the pod first lands on; volumes are not
portable. Fine for singletons. (Longhorn came and went: ADR-0005,
superseded by ADR-0009. The workers still carry an unused ~1.8 TiB XFS
partition from that era — reclaiming it needs an EPHEMERAL wipe and is
deferred.)

## Repository documentation

### Architecture map

[`ARCHITECTURE.md`](./ARCHITECTURE.md) — the entry point to the live
system: what is running, where each piece is configured, how changes
reach the cluster, what a human must do by hand, and how to verify. It
states structure, never values; values live in the file that owns them.
