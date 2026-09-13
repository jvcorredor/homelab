---
title: Storage
description: How local-path-provisioner works, what node-local volumes mean for workloads, and the disk history the workers still carry.
---

The cluster's default — and only — `StorageClass` is **`local-path`**,
installed from the upstream manifest by
[`terraform/bootstrap/local-path.tf`](https://github.com/jvcorredor/homelab/blob/main/terraform/bootstrap/local-path.tf).

## What a PVC actually does

`local-path-provisioner` creates a directory on **the node where the
consuming pod first lands**, and binds the `PersistentVolume` to it. From
then on the volume is effectively pinned there:

- A pod that later moves to another node cannot see its volume. For
  workloads that are pinned to a node anyway (a singleton, a
  node-specific daemon), that is fine.
- There is no replication: if the node's disk dies, the volume dies with
  it. Nothing in the floor backs it up.
- The provisioner's helper pods need `hostPath`. The cluster-wide Pod
  Security default is `baseline`, which forbids `hostPath`, so the
  `local-path-storage` namespace alone is labelled `privileged` — every
  other namespace stays at `baseline`.

That is the whole model. It is deliberately the simplest thing that
works, and it forces storage decisions to be explicit instead of hidden
behind a distributed filesystem.

## The disk history on the workers

Each node's install disk is `/dev/nvme0n1` (see
[`talos/patches/nodes/`](https://github.com/jvcorredor/homelab/tree/main/talos/patches/nodes)).
Workers cap their `EPHEMERAL` volume at 200 GiB — a leftover from when
Longhorn carved a dedicated ~1.8 TiB XFS partition out of each worker's
disk ([ADR-0005](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0005-longhorn-as-named-non-default-storageclass.md),
superseded by
[ADR-0009](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0009-barebones-reset.md)).

That partition still sits unused on each worker. Reclaiming it means
wiping `EPHEMERAL` — XFS cannot shrink — so the space returns whenever a
storage layer is rebuilt, not before.

## What would change this

If a workload ever needs a volume that survives its node, that is a new
decision with a new ADR: either re-scope the workload to a node it lives
on, or rebuild a storage layer deliberately. The Longhorn-era ADRs record
what that looked like and why it was removed.
