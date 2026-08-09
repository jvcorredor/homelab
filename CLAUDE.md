# CLAUDE.md

Guidance for Claude Code working in this repository.

## Repository Overview

The Rockingham Homelab: a 6-node bare-metal Kubernetes cluster (`rockingham`)
running Talos Linux. As of the 2026-08-09 barebones reset (ADR-0009) the
cluster runs the floor only — Cilium, Gateway API CRDs, local-path storage,
metrics-server — and **there is no app-management layer**: no ArgoCD, no
ESO, no cert-manager. The lab previously had a full GitOps/DNS/preview
stack; it was backed out because the operator hadn't understood it, and
this is a pedagogical homelab. Layers get re-added by hand, one at a time,
as learning exercises.

Two Terraform roots — `terraform/gcp/` (project skeleton, tfstate bucket,
CI WIF) and `terraform/bootstrap/` (Gateway API CRDs → Cilium → local-path
→ metrics-server). Everything else was removed; do not reintroduce managed
addons casually — installing something by hand and understanding it is the
admission price now.

[`CONTEXT.md`](./CONTEXT.md) is the canonical glossary (cluster name, LB
pool, IP ranges, storage). The load-bearing decisions behind that
vocabulary live in [`docs/adr/`](./docs/adr/) — ADR-0002 (Cilium) and
ADR-0004 (CI-driven apply for the gcp root) are in force; most others were
superseded by ADR-0009. Per-root READMEs under `terraform/` and `talos/`
cover their own areas. Read CONTEXT once before working in this repo.
