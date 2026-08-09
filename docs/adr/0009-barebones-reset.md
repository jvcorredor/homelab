# ADR-0009: Barebones reset — back out everything above Talos + Cilium

- **Status:** Accepted
- **Date:** 2026-08-09

## Context

The cluster accumulated a large surface between 2026-05-10 and
2026-05-14: ArgoCD app-of-apps GitOps, ESO + cert-manager with
cluster→GCP Workload Identity Federation, a public preview-environment
surface via Cloudflare Tunnel (ADR-0006), self-hosted observability
(ADR-0008), Longhorn distributed storage (ADR-0005), Harbor, two ARC
runner scale sets, and a split-horizon DNS design (ADR-0003).

Most of it was installed by an AI agent in a short burst. The operator's
assessment afterward: the layers were never understood, the preview
surface and ARC pools carried no real traffic in 90 days, Longhorn's
only consumers were the observability stack and Harbor, and Harbor sat
Degraded for days unnoticed. A homelab whose operator cannot explain
what is running on it is not serving its purpose.

The homelab is pedagogical. Its value is the operator understanding
every layer. The way back to that is to return to a floor the operator
does understand — Talos + Kubernetes + Cilium — and rebuild each layer
deliberately, by hand, as a learning exercise.

## Decision

Tear the cluster back to a **barebones floor** and rebuild from there.
The floor is:

- Talos Linux machine config (stock installer on every node)
- Kubernetes
- Cilium (CNI, kube-proxy replacement, LB IPAM, L2 announcements,
  Gateway API controller) — ADR-0002 stands
- Gateway API CRDs (Cilium's controller needs them; the shape is
  "free" with Cilium)
- local-path-provisioner (default StorageClass — Phase 1 storage)
- metrics-server

Removed in the reset (each superseded ADR carries the detail):

| Removed | Supersedes |
|---|---|
| ArgoCD + app-of-apps (`kubernetes/apps/`) | ADR-0001 (amended) |
| cert-manager + wildcard cert + LE ClusterIssuer | ADR-0003 |
| ESO + cluster WIF pool/provider + OIDC bucket | ADR-0007 |
| Preview surface: cloudflared, `projects` Gateway, reaper, wrappers | ADR-0006 |
| Cloudflare provider entirely (tunnel, ACM pack, apex records) | ADR-0006 |
| Observability: kube-prometheus-stack, Loki, Alloy | ADR-0008 |
| Longhorn + Talos iscsi/util-linux extensions + UserVolume | ADR-0005 |
| Harbor | (was #221) |
| ARC controller + both runner scale sets + GitHub App creds | — |
| Split-horizon DNS: Cloud DNS zone, AdGuard, NS delegation | ADR-0003 |
| The docs site (Astro shell under `docs/`); ADRs stay as markdown | — |

GCP-side, only the project skeleton survives: the project itself, the
tfstate GCS bucket, the `talos-cluster-secrets` GSM container (the one
irreplaceable file's backup), and the CI plan/apply service accounts
with the GitHub OIDC WIF pool (ADR-0004 stands — CI apply for
`terraform/gcp/` keeps working).

Rebuilding a layer means: picking it by hand, installing it by hand,
and being able to explain it — not re-running the old automation.

## Consequences

**Positive**

- The operator can enumerate and explain every running component.
- Steady-state external cost drops to ~$0 (the $10/mo ACM pack and all
  per-resource GCP costs are gone; the GCP project itself is free-tier
  quiet).
- The dependabot/CI noise from the docs site and preview workflows
  stops.
- Every layer re-added later will be understood, because understanding
  it is the admission price.

**Negative / ongoing**

- `jackhall.dev` DNS lapses: the Cloudflare zone is empty and the
  Cloud DNS zone is destroyed. Nothing used the domain but the lab.
- No TLS, no GitOps, no external secrets, no backups beyond the
  Talos-secrets GSM container, no observability. Each returns only
  when rebuilt.
- The workers' disks keep a now-unused ~1.8 TiB XFS partition from the
  Longhorn UserVolume era; reclaiming it requires an EPHEMERAL wipe
  and is deferred to whenever storage is rebuilt.

## Alternatives Considered

### Slim down but keep ArgoCD/ESO/cert-manager

Rejected. Those were the layers the operator explicitly flagged as
ununderstood; keeping them would keep the gap. They can be rebuilt
later as learning exercises — the ADRs (superseded) record what they
were for.

### Move the apex back to Cloud DNS instead of letting DNS lapse

Rejected. The only consumer of any `jackhall.dev` name was the lab.
With no lab services published, keeping authoritative DNS anywhere is
cost without purpose. The domain registration itself is untouched.

### Delete the GCP project too

Rejected. The project, tfstate bucket, and CI WIF machinery are the
scaffolding the rebuild will Terraform into; the `talos-cluster-secrets`
backup is the one irreplaceable artifact. Deleting the project would
protect nothing and cost the rebuild its starting point.
