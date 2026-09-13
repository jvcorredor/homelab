# The first durable VM: a Debian 13 cloud-image template that future utility
# VMs clone. It is never started and declares no identity or fixed address —
# user, SSH key, and IP are set on the clone, at clone time, via cloud-init.
resource "proxmox_virtual_environment_vm" "debian_13_template" {
  name        = "debian-13-template"
  description = "Debian 13 (trixie) generic-cloud base for durable utility VMs. Managed by OpenTofu: terraform/proxmox — change it in code, not the PVE UI."
  tags        = ["terraform", "template", "debian-13", "utility"]

  node_name = var.pve_node_name
  vm_id     = var.template_vm_id
  template  = true
  # Explicit, not just for clarity: leaving `started` unset stores null in
  # state and makes the provider re-mark the agent-derived address lists as
  # computed on every plan (a perpetual no-op diff).
  started = false

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

  # The image already on the host: datastore `local`, content type `iso`.
  # The `.img` name matters — PVE's dir plugin cannot address a `.qcow2` file
  # as iso content (pvesm path: "unable to parse directory volume name") —
  # but the bytes are the Debian qcow2. The provider imports it over SSH,
  # then grows the 3 GiB image to 8G.
  disk {
    datastore_id = "local-lvm"
    file_id      = "local:iso/debian-13-genericcloud-amd64.img"
    interface    = "scsi0"
    size         = 8
  }

  boot_order = ["scsi0"]

  network_device {
    bridge = "vmbr0"
  }

  # Present so clones can inject user/SSH/IP through cloud-init. DHCP keeps
  # the template itself address-agnostic.
  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  operating_system {
    type = "l26"
  }

  # Templates never run; without this the provider can wait forever for a
  # graceful shutdown that cannot happen.
  stop_on_destroy = true
}
