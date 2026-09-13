---
title: Upgrades and verification
description: How Talos, Cilium, and the floor's pinned components get upgraded, and what verifies the result.
---

Floor components are pinned in
[`terraform/bootstrap/variables.tf`](https://github.com/jvcorredor/homelab/blob/main/terraform/bootstrap/variables.tf).
An upgrade is usually: bump the pin, apply the root from a workstation,
and verify.

## Talos

The canonical runbook is
[`talos/README.md`](https://github.com/jvcorredor/homelab/blob/main/talos/README.md).
An upgrade is one node at a time: a worker canary, then the control
planes one at a time (etcd quorum), then the remaining workers.

Since Talos 1.14, `ghcr.io/siderolabs/installer` is no longer published;
installer images come from the Image Factory. Workers use the schematic
carrying the Longhorn prerequisites (`siderolabs/iscsi-tools` +
`siderolabs/util-linux-tools`, ID `613e1592...`), control planes the
empty schematic. The rebuild recipe lives in
[`talos/README.md`](https://github.com/jvcorredor/homelab/blob/main/talos/README.md#installer-images-image-factory).

```sh
# control planes: v1.13.0 -> v1.13.10 (ghcr image; still published for 1.13.x)
talosctl --nodes <cp-ip> upgrade --image ghcr.io/siderolabs/installer:v1.13.10

# workers: v1.13.0 -> v1.13.10 on the extension schematic
talosctl --nodes <ip> upgrade \
  --image factory.talos.dev/metal-installer/613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245:v1.13.10

# control planes: v1.13.10 -> v1.14.0 (empty schematic)
talosctl --nodes <cp-ip> upgrade \
  --image factory.talos.dev/metal-installer/376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba:v1.14.0

# workers: v1.13.10 -> v1.14.0 (extension schematic)
talosctl --nodes <ip> upgrade \
  --image factory.talos.dev/metal-installer/613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245:v1.14.0
```

Take the latest patch of each intermediate minor before crossing one
(`v1.13.0 -> v1.13.10 -> v1.14.0`), and snapshot etcd from a control
plane before touching the first one:
`talosctl --nodes 192.168.1.245 etcd snapshot talos/_out/etcd-<date>.snapshot`.

Two things to remember:

- **The node is cordoned and drained by the upgrade itself** (`--drain`
  defaults on, as does `--wait`). Control planes upgrade one at a time,
  never all at once.
- A same-version upgrade stages a new boot entry but does **not** reboot
  the node (observed on v1.13.0). Follow it with an explicit
  `talosctl --nodes <ip> reboot`.

Kubernetes is not upgraded by an OS upgrade; `talosctl upgrade-k8s` is a
separate operation, and the Cilium/Kubernetes support gap documented in
`variables.tf` applies to it.

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
