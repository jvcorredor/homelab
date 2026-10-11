# Parity inventory

What an instance of the RaptGroup platform can rely on, where `rockingham`
and the production GKE cluster differ, and what was decided about each
difference. [Issue #258](https://github.com/jvcorredor/homelab/issues/258)
owns this document until it closes; after that it is the living record.

An instance has to run unchanged on both clusters, so every primitive it
uses must exist on both or differ on purpose. Each row below ends in one
of three decisions:

- **Bridge** — install a layer on `rockingham` so the primitive exists
  there. It passes the admission test in
  [ADR-0012](./docs/adr/0012-platform-dev-and-incubation-purpose.md) and
  gets its own ADR.
- **Accepted difference** — the primitive stays different. The decision
  is recorded here, and the platform treats it as a rule.
- **Platform adapts** — the platform's contract changes so instances do
  not rely on the primitive.

This file states decisions and their reasons. Values (addresses, versions,
pins) live in the file that owns them, and vocabulary in
[`CONTEXT.md`](./CONTEXT.md). Platform issues are cited by number; that
repository is private, so nothing is quoted from it here.

**As of 2026-10-11** (homelab `main` at b066d51, live cluster checked the
same day). Every decision below is **Proposed**: the research supports it,
and the last column names who has the final word. Four platform issues are
still open and feed several rows (#1 developer experience, #2 delivery
model, #4 front door, #5 secrets); a row is re-grounded when its issue
lands.

## Inventory

| Row | Homelab today | On GKE | Proposed decision | Final call |
|-----|---------------|--------|-------------------|------------|
| Service type LoadBalancer | Cilium LB IPAM with L2 announcements ([`cilium.tf`](./terraform/bootstrap/cilium.tf)) | A billed public Google load balancer; none at launch, because the front door is Cloudflare Tunnel | Platform adapts: instances ship ClusterIP and HTTPRoute only. One guard against Service type LoadBalancer on both clusters | Platform #4 |
| Gateway API | Cilium; every Gateway still allocates a LoadBalancer Service | An in-cluster Gateway that stays ClusterIP; GKE-native classes are excluded; implementation not chosen | Accepted difference: two implementations, portable HTTPRoute subset. Install nothing now | Platform #4 |
| Persistent volumes | `local-path` only: node-pinned, no expansion | Persistent Disk CSI: zonal, expandable | Accepted difference. Manifests stay class-neutral; the volume is rebuildable | #258 |
| Volume snapshots | No snapshot CRDs, controller or CSI driver | Supported through the PD CSI driver | Accepted difference: object-store backups on both; no snapshot kinds in shared manifests | #258 |
| Certificate issuance | None, and nothing needs it: Cloudflare terminates public TLS | Not needed for ingress | Accepted difference now. Flips to a scoped cert-manager or bring-your-own certs if homelab Postgres gets a backup target | Platform |
| Object storage | None | GCS | Accepted difference: local driver, no archive. If a consumer appears, a real GCS bucket rather than an in-cluster S3 store | Platform |
| Pod identity | None: the API server issuer is a LAN address and discovery needs auth | Workload Identity Federation for GKE | Accepted difference now. Pre-design static-JWKS federation in [`terraform/gcp/`](./terraform/gcp/README.md); build it when a consumer is named | #258, gated on secrets |
| Image registry | Anonymous upstream pulls only; the builder VM is offline | Artifact Registry, no node config | Accepted difference for third-party images. Platform images wait for the platform's CI and registry choice | Platform #2 |
| Reachability | LAN only | Public through Cloudflare | **Bridge**, gated: Cloudflare Tunnel with Access default-deny and single-label hostnames. Accepted difference if collaborators never need it (#1) | Platform #4, #1 |
| GitOps controller | None; `tofu` and `helm` run from a workstation | Not installed; tofu bootstraps one | **Bridge**: trial Argo CD, pull-based, bootstrapped by tofu. Flux only if the trial fails a stated criterion | Platform #2 |
| Secrets into the cluster | None; hand-applied only | Secret Manager add-on or External Secrets Operator | **Bridge**, staged: External Secrets Operator with Secret Manager; first consumer is the tunnel token | Platform #5 |
| DNS and hostnames | None; the Cloudflare zone is empty | Cloudflare authoritative, single-label names | Platform adapts: a dedicated dev zone, wildcard record and tunnel route in OpenTofu | Operator, platform #4 |
| Health signal | None; `kubectl` by hand | Cloud Monitoring collects, no alerts | A `just smoke` probe per layer now (ADR-0012). Decide the alert path before the private beta | #258 |
| Postgres operator | Not installed | In-cluster CloudNativePG | Not yet investigated; follows storage, object storage, certs and secrets | Platform, #258 |
| Environment guardrails | No quota, LimitRange or NetworkPolicy | NetworkPolicy needs Dataplane V2, chosen at cluster creation | Not yet investigated; depends on #1 | Platform #1 |

Facts that bind several rows:

- **Replicated block storage is not available across six nodes.** Only
  two workers have free large partitions; the third holds the media
  volume and the control planes have no spare disk
  ([`CONTEXT.md`](./CONTEXT.md) storage section).
- **Pod identity, secrets and object storage form one chain.** The
  homelab cannot call a GCP API without a federated identity, so the
  secrets bridge and any real-GCS backup depend on the pod-identity
  design.
- **A layer needs a named consumer.** Each follow-up below names the
  open platform issue that pulls it; without one, the default is to
  accept the difference.

## Plan to close #258

This section is the working plan. Delete it when #258 closes; the
inventory above stays.

| Phase | What happens | Exit criterion |
|-------|--------------|----------------|
| 0. Settle the record | Choose where this document lives; confirm the next ADR number is free (0013 or later); correct facts that moved on 2026-10-11 | Location chosen, facts corrected |
| 1. Land the inventory | A docs-only change: the table above, wired into docs CI and mapped from [`ARCHITECTURE.md`](./ARCHITECTURE.md). Nothing is installed | Ten no-install rows carry a recorded decision |
| 2. Open the follow-ups | One issue per bridge and per trial, each naming its platform consumer, where it is declared in git and its smoke probe, joined by native `blocked_by` edges | Every bridge passes the ADR-0012 test on paper |
| 3. Run the trials | Agent-run follow-ups: the Argo CD trial, then identity and External Secrets, then the tunnel tracer | Each trial has a measured result and a passing probe |
| 4. Record the decisions | Proposed ADRs become Accepted per bridge; rows gain measured evidence; the evidence goes to platform #2, #4 and #5 | ADR and row agree for every bridge |
| 5. Close #258 | Check the issue's done-when list; re-ground any row whose platform issue landed first | #258 closed |

Follow-up issues to open in phase 2, with their dependencies:

| Follow-up | Consumer | Blocked by |
|-----------|----------|------------|
| Make `terraform/bootstrap` cold-bootstrappable (orphaned CRDs, stale comments) | The Argo CD trial | None |
| Protect `main` before any controller syncs from it | The Argo CD trial | None |
| Trial Argo CD on `rockingham` and measure its footprint; draft the delivery ADR | Platform #2 | The two above |
| Spike: static-JWKS workload identity federation to a scratch bucket | Platform #5 | None |
| Install External Secrets with the tunnel token as first consumer; draft the ADR | Platform #4, #5 | Argo CD trial, federation spike |
| Decide the dev and preview zone, and renew `jackhall.dev` (expires 2026-11-27) | Platform #4 | None |
| Cloudflare root in OpenTofu: tunnel, wildcard DNS, Access default-deny | Platform #4 | Zone decision, External Secrets |
| Tunnel tracer: `cloudflared` into a Gateway on `rockingham`, with a smoke probe; draft the ADR | Platform #4 | Cloudflare root, Argo CD trial |
| Record the instance contract (ClusterIP and HTTPRoute only, class-neutral storage, no snapshot kinds) | Platform #1 | None |
| Fix documentation drift in the storage page and `talos/README.md`; decide the Longhorn-era Talos extensions | None (hygiene) | None |

Decisions that belong to the operator or the platform:

1. Where this document lives (this file is the provisional answer).
2. Whether #258 closes when decisions are recorded, ADRs are Proposed
   and follow-ups exist, or only after the trials. Recommended: the
   former.
3. Whether agents may run the trials as follow-up issues under ADR-0012.
4. The `jackhall.dev` renewal, or another dev and preview domain.
5. Whether collaborators must reach homelab environments (#1).
6. Whether homelab Postgres environments archive WAL and rehearse
   restores. "No" keeps certs, object storage and pod identity as
   accepted differences.
7. Protecting `main` before a controller auto-syncs from it.
8. Retiring or keeping the Longhorn-era Talos extensions on the workers.
