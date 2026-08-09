# Talos

Machine configuration for the `rockingham` Talos cluster.

## Layout

- `patches/cluster/<topic>.yaml` — cluster-level machine config patches
  applied to every control plane (e.g. kube-apiserver flags). Same
  content goes onto every CP because Talos's `cluster:` section is
  cluster-wide. (Currently empty — the OIDC-issuer patch was removed in
  the 2026-08 barebones reset.)
- `patches/nodes/<hostname>.yaml` — per-node machine config patches
  (hostname, static address, install disk, VIP membership).
  Version-controlled.
- `_out/` — generated artifacts. Gitignored. Contains `secrets.yaml`,
  `talosconfig`, base `controlplane.yaml` / `worker.yaml`, and per-node
  patched configs.

## Cluster

- Name: `rockingham`
- Control plane endpoint: `https://192.168.1.240:6443` (shared VIP)
- Nodes (install disk `/dev/nvme0n1`, NIC `eno1` on every node):
  - `cp-01` — `192.168.1.245` (carries the `.240` VIP)
  - `cp-02` — `192.168.1.246` (carries the `.240` VIP)
  - `cp-03` — `192.168.1.247` (carries the `.240` VIP)
  - `worker-01` — `192.168.1.241`
  - `worker-02` — `192.168.1.242`
  - `worker-03` — `192.168.1.243`

Every node runs the stock installer (`ghcr.io/siderolabs/installer:v1.13.0`).
The factory schematic with iscsi/util-linux extensions was removed in the
2026-08 reset (it existed only for Longhorn; ADR-0005, superseded by
ADR-0009). Workers cap `EPHEMERAL` at 200 GiB — a leftover from carving
the disk for Longhorn. The ~1.8 TiB XFS partition that era created still
sits on each worker's disk unused; reclaiming it means wiping EPHEMERAL
(XFS can't shrink), deferred until a storage layer is rebuilt.

## First-time generation

Run from the repo root.

```sh
mkdir -p talos/_out

# 1. Generate cluster secrets (one-time, keep safe).
talosctl gen secrets -o talos/_out/secrets.yaml

# 2. Generate base controlplane.yaml / worker.yaml / talosconfig.
talosctl gen config rockingham https://192.168.1.240:6443 \
  --with-secrets talos/_out/secrets.yaml \
  --output-dir talos/_out/

# 3. Produce the per-node config for cp-01 by patching the base controlplane.
#    Cluster-level patches (if any exist) go first so per-node patches can
#    still override anything they need to.
talosctl machineconfig patch talos/_out/controlplane.yaml \
  --patch @talos/patches/nodes/cp-01.yaml \
  -o talos/_out/cp-01.yaml
```

Repeat step 3 for every node, using `talos/_out/worker.yaml` as the base
for the workers. Also point the talosconfig at the control planes:

```sh
export TALOSCONFIG=$PWD/talos/_out/talosconfig
talosctl config endpoint 192.168.1.245 192.168.1.246 192.168.1.247
```

## Applying to a node in maintenance mode

The node boots from install media, sits in maintenance mode at its DHCP
address, and accepts an insecure config push.

```sh
talosctl apply-config --insecure \
  --nodes 192.168.1.245 \
  --file talos/_out/cp-01.yaml
```

The node installs Talos to `/dev/nvme0n1`, reboots into the installed system,
and starts trying to form a cluster.

## Bootstrapping the first control plane

Only run this once, against the first control plane node, after it has
rebooted into the installed system.

```sh
export TALOSCONFIG=$PWD/talos/_out/talosconfig
talosctl config endpoint 192.168.1.240
talosctl config node 192.168.1.245

talosctl bootstrap
```

Then fetch the kubeconfig:

```sh
talosctl kubeconfig ./talos/_out/kubeconfig
```

## Adding more nodes

For each additional control plane node, write a `patches/nodes/<host>.yaml`
patch (matching its NIC, address, install disk) and repeat the patch +
apply-config steps. Workers use `worker.yaml` as the base instead of
`controlplane.yaml`.

## Upgrading Talos / changing machine config

Nodes run the stock installer, so upgrades are plain:

```sh
talosctl --nodes <ip> upgrade --image ghcr.io/siderolabs/installer:<new-version>
```

Note (observed on v1.13.0, 2026-08): an upgrade to the *same* version stages
the new boot entry but does not reboot the node — follow up with an explicit
`talosctl --nodes <ip> reboot`. Cordon and drain first for workers.

## Backing up `secrets.yaml`

`talos/_out/secrets.yaml` holds the cluster CA private key, etcd
bootstrap token, and KMS material. It is the only irreplaceable file
in the lab — losing it means the cluster can never be re-managed and
must be wiped and rebuilt from scratch. `talosconfig` and `kubeconfig`
can both be regenerated from `secrets.yaml`, so they don't need the
same care.

`terraform/gcp/` declares the GSM secret container `talos-cluster-secrets`.
Versions are uploaded out of band — pulling the value through Terraform
would land it in the GCS-backed state file too, doubling the surface
for no real benefit at homelab scale.

### Upload

After `talosctl gen secrets` (first-time generation) and after any
rotation:

```sh
gcloud secrets versions add talos-cluster-secrets \
  --project=rockingham-homelab \
  --data-file=talos/_out/secrets.yaml
```
