output "template_vm_id" {
  description = "VM ID of the Debian 13 template managed by this root."
  value       = proxmox_virtual_environment_vm.debian_13_template.vm_id
}

output "template_name" {
  description = "Name of the Debian 13 template; the clone source for durable utility VMs."
  value       = proxmox_virtual_environment_vm.debian_13_template.name
}
