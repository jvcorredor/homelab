variable "project_id" {
  description = "ID of the GCP project this root creates and owns. Must be globally unique across GCP."
  type        = string
  default     = "rockingham-homelab"
}

variable "project_name" {
  description = "Human-readable display name for the project."
  type        = string
  default     = "Rockingham Homelab"
}

variable "billing_account" {
  description = "Billing account ID (e.g. 0X0X0X-0X0X0X-0X0X0X) to attach the project to. Find with `gcloud billing accounts list`."
  type        = string
}

variable "org_id" {
  description = "Optional organization ID to nest the project under. Leave null for personal accounts with no org."
  type        = string
  default     = null
}

variable "folder_id" {
  description = "Optional folder ID to nest the project under. Mutually exclusive with org_id. Leave null for personal accounts."
  type        = string
  default     = null
}

variable "region" {
  description = "Default region for any regional resources. The provider wants a default even though every resource here is global."
  type        = string
  default     = "us-central1"
}

variable "tfstate_bucket" {
  description = "Globally-unique name of the GCS bucket holding Terraform state for this and other homelab roots. Must match the `bucket` value hardcoded in the backend block of any root that uses it."
  type        = string
  default     = "rockingham-homelab-tfstate"
}

variable "tfstate_bucket_location" {
  description = "Location for the tfstate bucket. Single region (cheaper) is fine for a homelab."
  type        = string
  default     = "US-CENTRAL1"
}

variable "github_repository" {
  description = "owner/repo of the GitHub repository allowed to impersonate the CI service account via Workload Identity Federation. Locks the WIF provider to a single repo so an OIDC token issued elsewhere cannot reach this project."
  type        = string
  default     = "RaptGroup/homelab"
}

variable "tf_ci_sa_id" {
  description = "Service account ID (the part before @) for the plan-only CI service account used by the terraform-plan workflow."
  type        = string
  default     = "tf-ci-plan"
}

variable "tf_ci_apply_sa_id" {
  description = "Service account ID (the part before @) for the apply CI service account used by the terraform-apply workflow. Holds roles/owner on the project; only impersonable from a workflow job that declares `environment: gcp` (env-scoped via the WIF binding)."
  type        = string
  default     = "tf-ci-apply"
}

variable "ci_apply_environment" {
  description = "GitHub deployment environment name that gates impersonation of the apply SA. The WIF binding restricts impersonation to OIDC tokens whose `environment` claim equals this value, so only workflow jobs that declare `environment: <this>` can mint a token for tf-ci-apply. Convention: environment names mirror Terraform root names (gcp ↔ terraform/gcp/)."
  type        = string
  default     = "gcp"
}
