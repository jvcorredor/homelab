# The first durable tenant: a BuildKit builder cloned from the Debian 13
# template. It is LAN-facing on purpose — local clients and, later, ARC
# runners reach buildkitd directly over vmbr0 — so the daemon listens on TCP
# and mutual TLS is the access boundary (ADR-0011, issue #253).
#
# Identity and address ride the provider-generated cloud-init user-data
# (`initialization` below); the daemon provisioning rides a vendor-data
# snippet. Every TLS key is generated on the VM, so no secret enters git or
# state.
resource "proxmox_virtual_environment_vm" "buildkit_01" {
  name        = "buildkit-01"
  description = "BuildKit builder (LAN-facing, mTLS). Managed by OpenTofu: terraform/proxmox — change it in code, not the PVE UI."
  tags        = ["terraform", "utility", "buildkit"]

  node_name = var.pve_node_name
  vm_id     = 201
  started   = true

  clone {
    vm_id = proxmox_virtual_environment_vm.debian_13_template.vm_id
    full  = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  # Grow the template's 8 GB disk. Setting any attribute on a cloned disk
  # resets the unset ones to their schema defaults; those defaults (cache
  # none, aio io_uring) match how the template was created, so only the
  # changes are named here. `discard` returns freed layer data to the thin
  # pool.
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 64
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    datastore_id = "local-lvm"

    # Outside the Optimum DHCP scope, the Cilium LB pool (.200-.230), and the
    # static cluster range (.240-.248, pve included).
    ip_config {
      ipv4 {
        address = "192.168.1.249/24"
        gateway = "192.168.1.1"
      }
    }

    user_account {
      username = "jack"
      keys     = [trimspace(file(pathexpand(var.vm_ssh_public_key_path)))]
    }

    vendor_data_file_id = proxmox_virtual_environment_file.buildkit_01_vendor_data.id
  }

  operating_system {
    type = "l26"
  }

  # Clones inherit the template's agent setting; explicit false keeps the
  # provider from waiting on an agent this guest does not run.
  agent {
    enabled = false
  }
}

# The provisioning script, uploaded to the `local` datastore as a snippet.
# Snippets are not an allowed content type by default — the README records
# the one-time host change.
resource "proxmox_virtual_environment_file" "buildkit_01_vendor_data" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.pve_node_name

  source_raw {
    data      = file("${path.module}/files/buildkit-01-vendor-data.yaml")
    file_name = "buildkit-01-vendor-data.yaml"
  }
}
