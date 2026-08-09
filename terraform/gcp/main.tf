provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  required_apis = [
    # serviceusage is the API that tofu itself calls to read/manage every
    # other google_project_service resource. It must be enabled before any
    # plan or apply that authenticates via a SA whose quota project is this
    # project (CI does — local ADC usually routes quota through the user's
    # personal default project, which masks this in dev). On a fresh GCP
    # account, enable it once by hand:
    #   gcloud services enable serviceusage.googleapis.com \
    #     --project=rockingham-homelab
    "serviceusage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
  ]
}

# The whole homelab GCP footprint is a single project so it can be torn
# down atomically. deletion_policy = "DELETE" overrides the v6 provider
# default of PREVENT so `tofu destroy` actually destroys.
resource "google_project" "lab" {
  name                = var.project_name
  project_id          = var.project_id
  billing_account     = var.billing_account
  org_id              = var.org_id
  folder_id           = var.folder_id
  auto_create_network = false
  deletion_policy     = "DELETE"
}

resource "google_project_service" "enabled" {
  for_each = toset(local.required_apis)

  project            = google_project.lab.project_id
  service            = each.value
  disable_on_destroy = false
}

# Terraform state lives here. GCS backend uses object generations for
# native state locking — no separate lock table needed (unlike S3+Dynamo).
resource "google_storage_bucket" "tfstate" {
  project  = google_project.lab.project_id
  name     = var.tfstate_bucket
  location = var.tfstate_bucket_location

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 30
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.enabled]
}

# --- Talos cluster secrets backup --------------------------------------------
#
# Container only. The cluster CA private key, etcd bootstrap token, and
# friends inside talos/_out/secrets.yaml are the one irreplaceable file
# in the lab — losing them means rebuilding the cluster from scratch.
#
# The secret VALUE is uploaded out of band via gcloud, deliberately:
# pulling it through TF would land it in the GCS-backed state file,
# doubling the surface, and any operator without a local secrets.yaml
# would either need a CI-plumbed env var or trigger a spurious
# "version will be destroyed" diff. The TF-managed container plus a
# manual `gcloud secrets versions add` keeps state idempotent and the
# value's provenance honest. See talos/README.md for the upload and
# restore commands.
resource "google_secret_manager_secret" "talos_cluster_secrets" {
  project   = google_project.lab.project_id
  secret_id = "talos-cluster-secrets"

  labels = {
    purpose  = "cluster-management"
    rotation = "talosctl-gen-secrets"
  }

  replication {
    auto {}
  }

  depends_on = [google_project_service.enabled]
}

# --- CI: GitHub OIDC Workload Identity Federation -----------------------------
#
# The github-actions pool + provider let GitHub Actions workflows in
# var.github_repository mint short-lived GCP credentials with no key
# material. Two service accounts: plan-only (viewer) and apply (owner,
# gated on the `gcp` deployment environment). See ADR-0004.

resource "google_iam_workload_identity_pool" "github_actions" {
  project                   = google_project.lab.project_id
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "OIDC pool trusted by GitHub Actions runners; per-repo trust is enforced on the provider, not the pool."

  depends_on = [google_project_service.enabled]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.lab.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"
  description                        = "Trusts GitHub-issued OIDC tokens; locked to ${var.github_repository}."

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
    "attribute.actor"      = "assertion.actor"
    # `environment` is only present on OIDC tokens issued for a job that
    # declares `environment: <name>` in its workflow definition. Plan-only
    # jobs omit it. The apply SA's workloadIdentityUser binding below pins
    # to a specific environment value, so a plan-only token (no
    # `environment` claim) can never satisfy that principalSet.
    "attribute.environment" = "assertion.environment"
  }

  attribute_condition = "assertion.repository == \"${var.github_repository}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Plan-only. roles/viewer covers everything `tofu plan` needs to read across
# the project (IAM, Storage objects in the tfstate bucket, project
# metadata) and is intentionally insufficient to mutate anything. Apply
# remains operator-only on a workstation with ADC.
resource "google_service_account" "tf_ci" {
  project      = google_project.lab.project_id
  account_id   = var.tf_ci_sa_id
  display_name = "Terraform CI plan-only"
  description  = "Used by .github/workflows/terraform-plan.yml. Project-scoped roles/viewer; cannot apply."

  depends_on = [google_project_service.enabled]
}

resource "google_project_iam_member" "tf_ci_viewer" {
  project = google_project.lab.project_id
  role    = "roles/viewer"
  member  = "serviceAccount:${google_service_account.tf_ci.email}"
}

# roles/viewer covers every `*.get` and `*.list` the plan SA needs to
# refresh resources during `tofu plan`, with one well-known exception:
# `storage.buckets.getIamPolicy`. GCS's IAM permission model split bucket
# policy reads out of the basic viewer role (the legacy ACL world made
# IAM-policy access more privileged than other read paths), so refreshing
# `google_storage_bucket_iam_member` against any bucket in this project
# 403s on plan. roles/iam.securityReviewer is the predefined role for
# "read every IAM policy in the project, change none of them" — exactly
# the shape plan refresh needs. Bound project-wide rather than
# bucket-scoped because the gap recurs the moment a second bucket-IAM
# binding (or any other resource backed by an API that withholds
# getIamPolicy from roles/viewer) gets added; one binding here covers
# them all.
resource "google_project_iam_member" "tf_ci_security_reviewer" {
  project = google_project.lab.project_id
  role    = "roles/iam.securityReviewer"
  member  = "serviceAccount:${google_service_account.tf_ci.email}"
}

resource "google_service_account_iam_member" "tf_ci_wif_user" {
  service_account_id = google_service_account.tf_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.repository/${var.github_repository}"
}

# Apply SA. roles/owner because tofu apply has to (re)create everything in
# this root, including the WIF pool/provider, project IAM bindings, and the
# tfstate bucket — narrower predefined roles either don't cover all of those
# or split them across so many bindings that the boundary stops being
# meaningful at homelab scale. The blast radius is bounded the other way: by
# the workloadIdentityUser binding below, which only lets workflow jobs that
# declare `environment: <var.ci_apply_environment>` impersonate this SA. The
# `gcp` GitHub environment carries deployment-branch restrictions and a
# required reviewer (set in the GitHub UI), so reaching this SA from CI
# requires (a) a push to main, (b) a workflow that opts into the
# environment, and (c) operator approval at run time. See ADR-0004.
resource "google_service_account" "tf_ci_apply" {
  project      = google_project.lab.project_id
  account_id   = var.tf_ci_apply_sa_id
  display_name = "Terraform CI apply"
  description  = "Used by .github/workflows/terraform-apply.yml. roles/owner on the project; impersonable only from a job declaring `environment: ${var.ci_apply_environment}`."

  depends_on = [google_project_service.enabled]
}

resource "google_project_iam_member" "tf_ci_apply_owner" {
  project = google_project.lab.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.tf_ci_apply.email}"
}

# Env-scoped impersonation. The principalSet is keyed on the
# `environment` claim, and the provider's attribute_condition already
# pins repository to var.github_repository — combined, this is
# equivalent to `repo:${var.github_repository}:environment:${var.ci_apply_environment}`.
# Tokens minted from a plan-style job (no `environment` claim) will not
# match this set, so the apply SA cannot be impersonated from
# terraform-plan.yml or any other workflow that omits the environment.
resource "google_service_account_iam_member" "tf_ci_apply_wif_user" {
  service_account_id = google_service_account.tf_ci_apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions.name}/attribute.environment/${var.ci_apply_environment}"
}
