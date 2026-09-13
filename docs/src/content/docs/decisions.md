---
title: Decision records
description: The load-bearing decisions behind the lab, with their current status. The canonical index lives in the repository.
---

Every load-bearing decision is recorded as an Architecture Decision
Record under
[`docs/adr/`](https://github.com/jvcorredor/homelab/tree/main/docs/adr):
what was chosen, what was rejected, and why. The canonical index is
[`docs/adr/README.md`](https://github.com/jvcorredor/homelab/blob/main/docs/adr/README.md);
this page mirrors it.

ADRs are **immutable once accepted**. A decision that changes is replaced
by a new ADR, and the old one's status becomes `Superseded by NNNN` — so
the history of the lab is readable in order, including the reasoning that
turned out to be wrong.

| # | Decision | Status |
|---|----------|--------|
| [0001](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0001-iac-strategy.md) | IaC strategy — thin Terraform plus ArgoCD app-of-apps | Accepted; the ArgoCD layer was removed by [0009](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0009-barebones-reset.md), the Terraform roots survive |
| [0002](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0002-cilium-unified-networking.md) | Cilium as the unified networking layer | Accepted — in force |
| [0003](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0003-public-domain-dns-tls-split-horizon.md) | Public-domain DNS and TLS, split-horizon | Superseded by [0009](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0009-barebones-reset.md) |
| [0004](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0004-ci-driven-terraform-apply.md) | CI-driven `terraform/gcp/` apply, env-gated and WIF-scoped | Accepted — in force |
| [0005](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0005-longhorn-as-named-non-default-storageclass.md) | Longhorn as a named non-default StorageClass | Superseded by [0009](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0009-barebones-reset.md) |
| [0006](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0006-public-preview-environments-via-cloudflare-tunnel.md) | Public preview environments via Cloudflare Tunnel | Superseded by [0009](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0009-barebones-reset.md) |
| [0007](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0007-eso-bootstrap-auth-via-cluster-wif.md) | External Secrets bootstrap auth via cluster WIF | Superseded by [0009](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0009-barebones-reset.md) |
| [0008](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0008-observability-as-self-hosted-stack.md) | Observability as a self-hosted stack | Superseded by [0009](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0009-barebones-reset.md) |
| [0009](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0009-barebones-reset.md) | Barebones reset — back out everything above Talos + Cilium | Accepted — current frame |
| [0010](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0010-docs-site-with-c4-diagrams.md) | Documentation site with C4 diagrams as a repo-layer artifact | Accepted — in force |

## Reading the superseded ones

Superseded ADRs are not dead weight: they are the record of what was
tried, what it cost, and why it went away. [ADR-0009](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0009-barebones-reset.md)
is the reset that defines the current cluster and explains what each
removed layer was; the ADRs it supersedes carry the details.
