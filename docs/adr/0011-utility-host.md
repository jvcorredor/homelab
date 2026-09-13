# ADR-0011: Utility host and declarative VM management

- **Status:** Accepted
- **Date:** 2026-09-13

## Context

The cluster is dedicated to `rockingham` and its floor is deliberately
minimal ([ADR-0009](./0009-barebones-reset.md)). Not every workload
belongs on it — a build host, a scratch VM for testing an OS or a
service, a utility that wants to live on a persistent VM — and those
workloads had no named home. The reset decided how layers above the
floor are added; it did not say where non-cluster workloads live.

The operator installed Proxmox VE 9.2.x by hand on a dedicated machine
at `pve.home.arpa` (`192.168.1.248`) to be that home: a hypervisor on
the LAN, outside the Talos cluster, with no cloud resources behind it.
KVM was validated end-to-end by booting a throwaway Debian 13 cloud VM
before anything was committed to the host; that VM also established
what "throwaway" means here — quick to create, quick to delete, never
expected to survive. The host sits outside the cluster, so it does not
re-open ADR-0009's floor decision, but it follows the same rule: it
was installed by hand and it is understood.

The host was live but undocumented, which is the drift the barebones
reset exists to prevent — a running system no one has agreed the rules
for. This ADR records its purpose, its boundary, and who owns which
VM.

## Decision

**`pve.home.arpa` is the lab's utility host, installed and maintained
by hand, and its durable VMs are managed as code.** Concretely:

1. **The host is manual.** Proxmox VE 9.2.x is installed and updated
   by hand. It is not a Talos node, not part of the ADR-0009 floor,
   and not managed by cloud Terraform — `terraform/gcp/` does not know
   it exists.
2. **Durable VMs are code.** A new `terraform/proxmox/` root owns VMs
   that should persist, using the `bpg/proxmox` provider. State lives
   in the existing `rockingham-homelab-tfstate` bucket under a
   root-specific prefix, alongside `terraform/gcp/` and
   `terraform/bootstrap/`. The PVE API token lives in a gitignored
   `terraform.tfvars` (already covered by the repo's `*.tfvars` rule)
   and never enters state or CI.
3. **Apply is workstation-local.** `terraform/proxmox/` is applied
   from a workstation with LAN access to the PVE API. There is no CI
   apply path — the API is not reachable from CI runners — matching
   `terraform/bootstrap/`'s lane; [ADR-0004](./0004-ci-driven-terraform-apply.md)'s
   CI apply remains scoped to `terraform/gcp/`.
4. **Throwaway VMs stay manual.** Experiments are created with `qm`
   or the PVE UI and deleted when done; they never appear in
   Terraform state. The UI is a viewer for durable VMs: reading is
   fine, editing there is drift, and `tofu plan` is how it surfaces.
5. **VM IDs carry ownership.** Durable, Terraform-managed VMs use IDs
   in the **2xx** range; throwaway, hand-made VMs use **9xx**. The
   ranges make ownership readable at a glance and keep manual
   creations from colliding with declared ones.

Deferred, on purpose:

- **VT-d / GPU passthrough** — not configured; it waits on the
  firmware prerequisite (VT-d/IOMMU enabled on the host) being met.
  VMs are CPU-only until then.
- **A builder VM (`buildkit-01`)** — the first candidate durable
  tenant, deliberately not built yet: a builder earns its place only
  when a build workload needs it. Docker builds remain on
  GitHub-hosted runners until then.

## Consequences

**Positive**

- The host is documented: purpose, management boundary, and VM
  ownership no longer live only in the operator's head.
- Durable VMs are reproducible. Config and state are in the repo, so
  rebuilding a VM is `tofu apply` rather than a remembered sequence
  of UI clicks.
- The cluster keeps its floor. Utility workloads have a home that is
  not `rockingham`, so ADR-0009's admission process does not have to
  stretch to cover them.
- Throwaways stay cheap: an experiment costs a `qm create` and a
  `qm destroy` — no state, no review, no cleanup debt.
- The ID ranges make intent visible in the UI: 2xx means "declared,
  change it through Terraform"; 9xx means "ephemeral, safe to
  destroy".
- No new external spend: the host is on the LAN, and the only cloud
  dependency is the state bucket that already exists.

**Negative / ongoing**

- Another hand-maintained system. PVE 9.2.x and every guest OS are
  operator-patched; nothing scans them, and no CI check notices a
  host that has fallen behind.
- No CI, no remote apply. Planning or applying `terraform/proxmox/`
  needs a workstation on the LAN with the API token in place. Losing
  that workstation or token means reconstructing access before
  anything can change.
- Drift is possible in the one direction the convention cannot block:
  a durable VM edited in the UI changes silently until someone runs
  `tofu plan`. "The UI is a viewer" is a rule, not enforcement.
- The ID convention is manual too — `qm` will happily create a 2xx
  ID by hand — but the collision then fails loudly at apply.
- The host is a single point of failure for its durable VMs. No HA
  and no backup path is recorded here; state can rebuild a VM, not
  the data inside it.
- GPU passthrough and `buildkit-01` are deferred, not answered. Each
  returns as its own decision when the prerequisite is met or a
  build workload earns it.

## Alternatives Considered

### Run the builder on the Talos cluster

Rejected. The cluster is dedicated to `rockingham`, and the floor is
deliberately minimal ([ADR-0009](./0009-barebones-reset.md)): a
builder would be a new always-on workload with registry credentials
and a cache, added to a cluster the reset exists to keep explainable.
If a builder ever belongs on the cluster, that reopens the floor
decision — it should not ride in as a side effect of wanting faster
builds.

### Raspberry Pi 4B as a remote `buildkitd` host

Rejected. The Pi is cheap and quiet, but it is arm64, and building
amd64 images means QEMU emulation on every layer; its only storage
path is USB. A builder slower than the CI runner it replaces is not
worth the rack space.

### A bare Debian build host with no hypervisor

Rejected. One host, one OS. The lab wants a utility host that can run
several durable VMs and any number of throwaways; a plain Debian
install would need containers and VMs grafted on later, and booting a
whole guest OS is exactly the throwaway pattern the host exists to
allow. Proxmox provides the VM boundary for free.

### No host at all — cloud runners only

Rejected. GitHub-hosted runners already cover the Docker builds that
exist today, which is why no builder VM is being created now. But
runners are CI: ephemeral, repo-scoped, and unable to host a durable
LAN service or a scratch guest-OS test. Choosing "no host" answers
the builder question and leaves the next utility-VM question homeless.
