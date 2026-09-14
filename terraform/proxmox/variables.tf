variable "pve_endpoint" {
  description = "Proxmox VE API endpoint. The FQDN is pve.home.arpa; the LAN IP is the default because the workstation resolver does not know the .home.arpa zone."
  type        = string
  default     = "https://192.168.1.248:8006/"
}

variable "pve_api_token" {
  description = "Proxmox API token, user@realm!tokenid=secret. Lives in the gitignored terraform.tfvars; it never enters state or CI (ADR-0011)."
  type        = string
  sensitive   = true
}

variable "pve_node_name" {
  description = "Name of the Proxmox node that owns the template."
  type        = string
  default     = "pve"
}

variable "pve_ssh_address" {
  description = "Address the provider's SSH client uses for the node. The disk import runs qm importdisk over SSH, and the token deliberately lacks the SDN privileges needed for bridge enumeration, so the address is pinned instead."
  type        = string
  default     = "192.168.1.248"
}

variable "pve_ssh_private_key_path" {
  description = "Unencrypted SSH private key (root@pve) used by the provider for the disk import. The provider does not read ~/.ssh/config."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "template_vm_id" {
  description = "VM ID of the Debian 13 template. 2xx means durable and Terraform-managed (ADR-0011); 200 is the base of the range."
  type        = number
  default     = 200
}

variable "vm_ssh_public_key_path" {
  description = "Operator SSH public key injected into durable VMs through cloud-init. Expanded with pathexpand because file() does not expand ~."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
