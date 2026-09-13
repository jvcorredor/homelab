terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.113.1"
    }
  }

  # Same bucket as terraform/gcp and terraform/bootstrap; different prefix.
  backend "gcs" {
    bucket = "rockingham-homelab-tfstate"
    prefix = "terraform/proxmox"
  }
}
