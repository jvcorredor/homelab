# `kubernetes/apps/jellyfin/`

Jellyfin media server — the first workload above the barebones floor
(ADR-0009) since the 2026-08-09 reset. Delivered by hand with the
official `jellyfin/jellyfin` Helm chart; there is no app-management
layer, so nothing here is ArgoCD-managed (issue #233).

## Shape

```
kubernetes/apps/jellyfin/
├── helm-values.yaml            # jellyfin chart values (Deployment + Service + PVC + HTTPRoute)
└── manifests/
    ├── namespace.yaml          # jellyfin Namespace (privileged PSA: media is a hostPath volume)
    └── gateway.yaml            # Cilium Gateway, HTTP listener, pinned to 192.168.1.200
```

The chart renders the `HTTPRoute` itself via its native `httpRoute`
support; the `Gateway` it attaches to lives in `manifests/gateway.yaml`
because the chart only wires up the route, not the gateway.

## Storage

| Volume  | Type       | Location                          |
|---------|------------|-----------------------------------|
| config  | local-path | PVC (binds to whatever node the pod lands on — worker-01) |
| media   | hostPath   | `/var/mnt/media` on worker-01     |
| cache   | emptyDir   | transient transcode cache         |

The media library is the 1.8 TiB XFS partition (`/dev/nvme0n1p5`,
label `u-longhorn`) that the Longhorn era carved out of worker-01's
disk. After the reset it sat unused; `talos/patches/nodes/worker-01.yaml`
re-claims it as an `ExistingVolumeConfig` named `media`, mounting it at
`/var/mnt/media` (no wipe needed — it was already clean XFS). The pod
mounts that path read-only; files are placed on the host out-of-band
(rsync/copy onto worker-01), not through the pod.

## LB IP allocation

| Resource                  | IP              |
|---------------------------|-----------------|
| Jellyfin Gateway          | `192.168.1.200` |

Out of the `.200`–`.230` Cilium pool from `terraform/bootstrap`
(ADR-0002). No DNS in the lab yet, so reach Jellyfin by IP:
`http://192.168.1.200/` on the LAN.

## Deploying

Requirements: `helm`, `kubectl` against the `rockingham` context.

```sh
# 1. Namespace + Gateway (manifest-only resources).
kubectl apply -f manifests/namespace.yaml
kubectl apply -f manifests/gateway.yaml

# 2. The chart. Add the repo if it isn't present yet.
helm repo add jellyfin https://jellyfin.github.io/jellyfin-helm
helm repo update
helm upgrade --install jellyfin jellyfin/jellyfin \
  --version 3.2.0 \
  --namespace jellyfin \
  --values helm-values.yaml \
  --wait
```

## Post-install

First-run setup: browse to `http://192.168.1.200/`, walk the wizard,
and add the `/media` library. Point your media files onto
`worker-01:/var/mnt/media` (e.g. rsync through a temp pod with the
media hostPath mounted, or `talosctl cp` for small transfers — it
copies *out of* the node, so uploading needs a pod or an scp/rsync
path onto the host). The Jellyfin container reads `/media` read-only.

## PSA note

The namespace is `privileged` because the media volume is a `hostPath`
mount, which the cluster-wide PodSecurity `baseline` default rejects —
same reasoning as `local-path-storage`. If that ever feels too broad,
the alternative is moving media to a proper volume (NAS/NFS) so the
namespace can drop back to `baseline`/`restricted`.
