---
title: GCP project
description: The cloud-side skeleton — one project holding the Terraform state, the cluster-secrets backup, and the CI identities.
---

Everything cloud-side lives in a single GCP project,
`rockingham-homelab`, owned by
[`terraform/gcp/`](https://github.com/jvcorredor/homelab/tree/main/terraform/gcp).
Project-level isolation bounds the blast radius: if the credentials or
resources in this project are compromised, nothing else is.

## What the root owns

| Resource | Purpose |
|----------|---------|
| The project + five APIs | `serviceusage`, `cloudresourcemanager`, `iam`, `secretmanager`, `storage` |
| GCS bucket `rockingham-homelab-tfstate` | The OpenTofu state for **both** roots, with versioning and a retention lifecycle |
| GSM container `talos-cluster-secrets` | Holds versions of the one irreplaceable Talos file; Terraform manages the container, never the value |
| Workload Identity Federation pool `github-actions` | Lets GitHub Actions mint short-lived GCP credentials — no service-account keys exist |
| `tf-ci-plan` service account | `roles/viewer` + `roles/iam.securityReviewer`; used by plan jobs |
| `tf-ci-apply` service account | `roles/owner`; usable only by jobs that declare the `gcp` environment |

The exact resources live in
[`main.tf`](https://github.com/jvcorredor/homelab/blob/main/terraform/gcp/main.tf);
names and IDs that vary are variables in
[`variables.tf`](https://github.com/jvcorredor/homelab/blob/main/terraform/gcp/variables.tf).

## State

Both Terraform roots use the same GCS bucket, each under its own prefix
(`terraform/gcp` and `terraform/bootstrap`). State locking rides on GCS
object generations, which is why plan jobs get `-lock=false`: the viewer
service account cannot write the lock object. The apply job keeps locking
enabled.

## Two identities, one boundary

The WIF provider maps GitHub's OIDC claims into Google identities:

- a **repository-scoped** binding (`attribute.repository`) lets any
  workflow in the repo impersonate `tf-ci-plan`;
- an **environment-scoped** binding (`attribute.environment`) is the only
  way to impersonate `tf-ci-apply`, so a job must declare
  `environment: gcp` to apply.

That split is the core of
[ADR-0004](https://github.com/jvcorredor/homelab/blob/main/docs/adr/0004-ci-driven-terraform-apply.md):
a token compromised during plan cannot apply, and the environment's
required reviewer sees the apply before it runs. See
[CI apply path](./ci/) for the workflow side.

## Running it

CI applies this root on merge to `main`; details are in the
[CI page](./ci/) and the
[root README](https://github.com/jvcorredor/homelab/blob/main/terraform/gcp/README.md).
The first-ever apply is manual: the backend bucket it will use does not
exist yet, and the billing account must be supplied by hand. That is one
of the steps no CI check can do for you.
