---
title: Upgrades and verification
description: How Talos, Cilium, and the floor's pinned components get upgraded, and what verifies the result.
---

Floor components are pinned in
[`terraform/bootstrap/variables.tf`](https://github.com/jvcorredor/homelab/blob/main/terraform/bootstrap/variables.tf).
An upgrade is usually: bump the pin, apply the root from a workstation,
and verify.

## Talos

Nodes run the stock installer, so an upgrade is one command per node:

```sh
talosctl --nodes <ip> upgrade --image ghcr.io/siderolabs/installer:<new-version>
```

Two things to remember:

- **Cordon and drain workers first.** Control planes upgrade one at a
  time, never all at once.
- A same-version upgrade stages a new boot entry but does **not** reboot
  the node (observed on v1.13.0). Follow it with an explicit
  `talosctl --nodes <ip> reboot`.

## Cilium

Cilium does not support skipping minor versions. Upgrade **one minor at a
time** and `tofu apply` between each hop:

1. Bump `cilium_chart_version` in `variables.tf` by one minor.
2. `tofu apply` from the workstation.
3. Verify (`just smoke`), then repeat for the next minor.

The cluster is on a version whose e2e support trails the Kubernetes
minor by one; closing that gap is gated on the next Cilium minor, not on
a config change. The constraint is documented in the variable's
description and in the
[root README](https://github.com/jvcorredor/homelab/blob/main/terraform/bootstrap/README.md).

## local-path-provisioner and metrics-server

Both are pinned by variable (`local_path_version`,
`metrics_server_chart_version`) and upgraded by bumping the pin and
applying the root. Neither has an ordering relationship beyond "Cilium is
already up".

## Verification

| What | Where it runs | What it proves |
|------|---------------|----------------|
| `tofu fmt -check`, `validate`, `plan` | CI, `gcp` root only | The cloud root is well-formed and reviewable before merge |
| `just check-docs` | Workstation and CI | Every relative link in the live docs resolves |
| `just smoke` | Workstation, against the current kubeconfig | Cilium connectivity on the running cluster |
| gitleaks | CI on PRs | No secrets in the diff |

Two honest gaps: the `bootstrap` root has **no CI plan** and the Talos
patches have **no schema check**, so treat a local `tofu plan` before any
bootstrap change as required. Nothing detects drift between the running
cluster and the bootstrap state.
