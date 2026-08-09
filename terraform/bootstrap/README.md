# terraform/bootstrap

Brings the Talos cluster from "kubeconfig works, nothing installed" to the
barebones floor in a single `tofu apply`.

The floor (post-2026-08 reset, ADR-0009): Gateway API CRDs → Cilium →
local-path-provisioner → metrics-server. There is deliberately **no**
app-management layer here — no ArgoCD, no cert-manager, no ESO. Workloads
above the floor are applied by hand.

Applied locally from the operator's workstation; there is no CI apply for
this root (ADR-0004 covers `terraform/gcp/` only).

## Bootstrap order

Components are installed in this exact order, enforced via `depends_on`
between resources. Re-running on a fresh cluster cannot apply pieces in
the wrong order.

1. **Gateway API CRDs** — `experimental-install.yaml` from
   `kubernetes-sigs/gateway-api`. Applied first so Cilium's operator
   finds the CRDs at startup and registers its `GatewayClass`.
2. **Cilium** — Helm chart with the Talos values pinned in `cilium.tf`,
   plus a `CiliumLoadBalancerIPPool` covering `192.168.1.200`–`230` and
   a `CiliumL2AnnouncementPolicy` that excludes control-plane nodes.
3. **local-path-provisioner** — the default StorageClass, applied from
   the upstream manifest. The `local-path-storage` namespace is labelled
   `privileged` for PSA because the provisioner's helper pods use
   hostPath.
4. **metrics-server** — Helm chart with the Talos-required args
   (`--kubelet-insecure-tls`: Talos issues kubelet certs from its own
   machine CA). Gives `kubectl top`.

## Usage

```sh
tofu init        # pulls providers, configures the GCS backend
tofu plan
tofu apply
```

Every variable has a default — `tofu apply` runs with no `terraform.tfvars`.
The providers read the Talos-issued kubeconfig at
`../../talos/_out/kubeconfig` by default (override with
`-var kubeconfig_path=...`).

## Upgrading Cilium

Cilium does not support skipping minor versions on upgrade. Bump
`cilium_chart_version` one minor at a time and `tofu apply` between each.
The cluster is on 1.19.x (e2e-tested by Cilium to k8s 1.35, one minor
behind the cluster's 1.36); closing that gap needs Cilium 1.20 once it
lists k8s 1.36 as tested.
