# terraform/gcp

The GCP-side skeleton for the homelab — deliberately minimal after the
2026-08 barebones reset (ADR-0009).

Owns, in one `tofu apply`:

- The `rockingham-homelab` project itself (billing, org/folder placement).
- The GCS **tfstate bucket** every Terraform root's state lives in
  (versioned, state-locking via object generations).
- The `talos-cluster-secrets` GSM secret **container** — the off-site
  backup of the one irreplaceable file in the lab (`talos/_out/secrets.yaml`).
  The value is uploaded out of band via `gcloud secrets versions add`;
  see `talos/README.md`.
- The **CI credentials**: the `github-actions` WIF pool + `github`
  provider (locked to `RaptGroup/homelab`), the plan-only `tf-ci-plan`
  service account (roles/viewer + securityReviewer), and the `tf-ci-apply`
  service account (roles/owner, impersonable only from a workflow job
  declaring `environment: gcp` — ADR-0004).

Nothing else: no DNS zone, no cert-manager/ESO service accounts, no
cluster-WIF pool, no Artifact Registry, no backups bucket. Those came
from layers that were backed out in the reset; if a layer returns, its
GCP resources return with it, deliberately.

## Usage

```sh
tofu init
tofu plan    # reads via ADC or the CI plan SA
tofu apply   # locally with operator ADC, or via CI (see below)
```

`terraform.tfvars` (gitignored) carries only `billing_account`.

## CI

PRs get a plan via `.github/workflows/terraform-plan.yml`. Merges to
`main` apply via `.github/workflows/terraform-apply.yml`, held for
approval by the `gcp` GitHub deployment environment (required reviewer =
repo owner). See ADR-0004 for the trust model.

## Setup on a fresh GCP account

1. `gcloud services enable serviceusage.googleapis.com --project=<id>`
   once by hand (tofu needs it to manage the other APIs).
2. Create `terraform.tfvars` with `billing_account = "..."`.
3. `tofu apply` locally. The backend block then holds state in the
   bucket this root just created — the first apply uses
   `-backend=false` or a migrated state; see git history if this ever
   needs to be re-derived.
