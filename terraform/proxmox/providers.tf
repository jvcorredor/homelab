provider "proxmox" {
  endpoint  = var.pve_endpoint
  api_token = var.pve_api_token

  # PVE serves a self-signed certificate; there is no CA for pve.home.arpa
  # to trust.
  insecure = true

  # The template's disk is imported from an existing file on the host whose
  # content type is `iso`, so the provider imports it over SSH (qm
  # importdisk) rather than the API. API-token auth has no password to hand
  # SSH, and the provider does not read ~/.ssh/config — name the key
  # explicitly.
  ssh {
    agent       = false
    username    = "root"
    private_key = file(pathexpand(var.pve_ssh_private_key_path))

    node {
      name    = var.pve_node_name
      address = var.pve_ssh_address
    }
  }
}
