# Architecture

The entry point to the live Rockingham Homelab: what is running, where it
is configured, how changes reach the cluster, and how to verify them.

This document states **structure, never values**. Addresses, ranges,
versions, chart pins, and node inventories live in the file that owns them
and are reached by link. Vocabulary lives in [`CONTEXT.md`](./CONTEXT.md),
decisions and their history in [`docs/adr/`](./docs/adr/README.md), and
procedures in the per-root READMEs. A rendered copy with C4 diagrams
lives at <https://jvcorredor.github.io/homelab/>.

## What is live

The cluster is `rockingham`: six bare-metal nodes — three control planes,
three workers — running Talos Linux. Node identity (addresses, the shared
control-plane VIP, install configuration) is per-node under
[`talos/patches/nodes/`](./talos/patches/nodes/), with the inventory
table in [`talos/README.md`](./talos/README.md).

As of the 2026-08-09 barebones reset
([ADR-0009](./docs/adr/0009-barebones-reset.md)), the cluster runs the
**floor** only:

| # | Module | Configured in | Role |
|---|--------|---------------|------|
| 1 | Gateway API CRDs | [`gateway-api-crds.tf`](./terraform/bootstrap/gateway-api-crds.tf) | Must exist before Cilium's operator starts |
| 2 | Cilium | [`cilium.tf`](./terraform/bootstrap/cilium.tf) | CNI, kube-proxy replacement, LB IPAM + L2 announcements, Gateway API controller — the only thing in the data plane ([ADR-0002](./docs/adr/0002-cilium-unified-networking.md)) |
| 3 | local-path-provisioner | [`local-path.tf`](./terraform/bootstrap/local-path.tf) | Default `StorageClass`; volumes are node-local, not portable |
| 4 | metrics-server | [`metrics-server.tf`](./terraform/bootstrap/metrics-server.tf) | `kubectl top` and the resource-metrics APIs |

Bootstrap order is enforced by `depends_on`; see
[`main.tf`](./terraform/bootstrap/main.tf) for the order and
[`terraform/bootstrap/README.md`](./terraform/bootstrap/README.md) for
the operating detail.

The cloud side is one project, owned by
[`terraform/gcp/`](./terraform/gcp/README.md): the project and its
required APIs, the tfstate bucket, the `talos-cluster-secrets` GSM
container, and the GitHub OIDC WIF pool with the CI plan/apply identities
([ADR-0004](./docs/adr/0004-ci-driven-terraform-apply.md)).

Everything above the floor — ArgoCD, cert-manager, External Secrets, the
Cloudflare preview surface, observability, Longhorn, Harbor, ARC — was
removed in the reset. Each removed layer keeps a superseded ADR; consult
the [ADR index](./docs/adr/README.md) before assuming an old document
describes the present.

## How changes reach the cluster

| Change | Path | Gate |
|--------|------|------|
| `terraform/gcp/` | [PR plan](./.github/workflows/terraform-plan.yml); merge to `main` triggers [apply](./.github/workflows/terraform-apply.yml) | `gcp` GitHub environment: branch-restricted, required reviewer ([ADR-0004](./docs/adr/0004-ci-driven-terraform-apply.md)) |
| `terraform/bootstrap/` | `tofu apply` from a workstation holding the Talos-issued kubeconfig | none — no CI apply for this root |
| Talos machine config | `talosctl` per node, per the [runbook](./talos/README.md) | none |
| Anything above the floor | applied by hand (`kubectl`, `helm`) | the admission rule below |

The apply gate is a human approval at run time, not just review at PR
time: the apply job sits behind the `gcp` deployment environment.

## What only a human can do

Steps with no code path, which no CI check will catch:

- **Fresh GCP account** — enable `serviceusage.googleapis.com` by hand,
  provide the billing account, and perform the first apply without the
  backend the root is about to create. See
  [`terraform/gcp/README.md`](./terraform/gcp/README.md).
- **Cluster-secrets backup** — after `talosctl gen secrets` and after any
  rotation, upload a new version with `gcloud secrets versions add`.
  Terraform manages the container only, deliberately; see
  [`talos/README.md`](./talos/README.md).
- **GitHub environments** — create the `gcp` deployment environment with
  its branch restriction and required reviewer, and set the repository
  variables/secrets from the root's outputs. These protection rules are
  UI state that no code holds.
- **Talos bring-up** — generate secrets and base configs, patch per node,
  apply in maintenance mode, bootstrap the first control plane once, and
  fetch the kubeconfig. See [`talos/README.md`](./talos/README.md).

## Verification

| What | Where it runs | What it proves |
|------|---------------|----------------|
| `tofu fmt -check`, `validate`, `plan` | CI, `gcp` root only ([plan workflow](./.github/workflows/terraform-plan.yml)) | The `gcp` root is well-formed and its plan is reviewable before merge |
| `just check-docs` | Workstation and CI ([docs-lint workflow](./.github/workflows/docs-lint.yml)) | Every relative link in the live docs resolves ([script](./scripts/check-docs.sh)) |
| `just smoke` | Workstation, against the current kubeconfig ([justfile](./justfile)) | Cilium connectivity on the running cluster |
| gitleaks | CI on PRs ([secrets-scan workflow](./.github/workflows/secrets-scan.yml)) | No secrets in the diff |

Not verified anywhere: the `bootstrap` root has no CI plan, the Talos
patches have no schema check, and nothing detects drift between the
running cluster and the bootstrap state. Treat a local `tofu plan` before
any bootstrap change as required.

## Adding a layer

Pick it by hand, install it by hand, and be able to explain it — that is
the admission price ([ADR-0009](./docs/adr/0009-barebones-reset.md)).
Where it goes:

- **Floor changes** (a bootstrap component, a Cilium bump) — edit
  [`terraform/bootstrap/`](./terraform/bootstrap/README.md), applied from
  a workstation. Cilium upgrades one minor at a time.
- **GCP-side resources** — [`terraform/gcp/`](./terraform/gcp/README.md);
  changes reach GCP through CI apply.
- **Workloads above the floor** — applied by hand for now. If a layer
  earns management, that is a new decision with a new ADR.

## Where facts live

| Kind of fact | Home |
|--------------|------|
| Vocabulary and naming | [`CONTEXT.md`](./CONTEXT.md) |
| Decisions and their history | [`docs/adr/`](./docs/adr/README.md) |
| Values — addresses, ranges, versions, pins | The `.tf`, patch, or workflow that uses them |
| Procedures and runbooks | [`terraform/*/README.md`](./terraform), [`talos/README.md`](./talos/README.md) |
| Structure and cross-cutting rules | This file |

This table is the ownership rule: when a value moves, this document is not
supposed to change. Every file reference above is a relative markdown
link, checked by [`scripts/check-docs.sh`](./scripts/check-docs.sh).
