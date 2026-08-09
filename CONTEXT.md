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

Talos + Kubernetes + Cilium + Gateway API CRDs + local-path-provisioner +
metrics-server. Installed by `terraform/bootstrap/`; nothing else is
managed. Anything above this floor is added by hand and understood by hand
(ADR-0009).

### Cilium (unified networking layer)

A single Helm release covering four roles: CNI, kube-proxy replacement,
LB IPAM + L2 announcements, and Gateway API. The only thing that touches
the data plane. See ADR-0002.

### LB pool (`192.168.1.200`–`192.168.1.230`)

The range Cilium hands out to `Service`s of type `LoadBalancer` via
`CiliumLoadBalancerIPPool`. No pins are currently load-bearing; the
pre-2026-08 allocations (`.200` AdGuard, `.201` lab Gateway) are gone.

### Static cluster range (`192.168.1.240`–`192.168.1.247`)

- `.240` — control-plane VIP (shared by `cp-01`/`cp-02`/`cp-03`).
- `.241`/`.242`/`.243` — workers.
- `.245`/`.246`/`.247` — control planes.

Static, set in the per-node Talos patches under `talos/patches/nodes/`.

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

## Repository conventions

### IaC split

Two Terraform roots, each applied with `tofu` against the GCS backend:

- `terraform/gcp/` — the project skeleton (project, tfstate bucket,
  `talos-cluster-secrets` GSM container, CI plan/apply SAs + GitHub OIDC
  WIF pool). Applied by CI on merge to `main` (ADR-0004), environment
  `gcp` with required-reviewer approval.
- `terraform/bootstrap/` — the cluster floor (Gateway API CRDs → Cilium →
  local-path → metrics-server). Applied locally from the operator's
  workstation; no CI apply for this root.

There is no app-management layer. Workloads above the floor are applied
by hand (`kubectl`/`helm`) — that is the point of the reset.

## CI/CD

- `terraform-plan.yml` — PR-time plan for the `gcp` root, via the
  plan-only `tf-ci-plan` SA (roles/viewer).
- `terraform-apply.yml` — merge-time apply for the `gcp` root, via the
  env-scoped `tf-ci-apply` SA (roles/owner, impersonable only from jobs
  declaring `environment: gcp`; the environment carries a required
  reviewer). See ADR-0004.
- `secrets-scan.yml` — gitleaks on PRs.
