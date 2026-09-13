# terraform/proxmox

Manages durable VMs on the utility host `pve.home.arpa` (Proxmox VE 9.2.x,
`192.168.1.248`) — the lab's non-cluster compute component ([ADR-0011](../../docs/adr/0011-utility-host.md)).
Today it owns one resource: the **Debian 13 cloud-image template** that
future durable utility VMs clone.

Throwaway VMs are not managed here. They are created with `qm` or the PVE
UI and destroyed when done — no state, no review, no cleanup debt.

## VM ID convention

| Range | Owner                   | Meaning                             |
| ----- | ----------------------- | ----------------------------------- |
| `2xx` | `terraform/proxmox`     | Durable, declared, change in code   |
| `9xx` | hand-made (`qm`/PVE UI) | Throwaway, safe to destroy          |

The template takes **200**, the base of the durable range, because it is
the first declared VM. `qm` will happily create a 2xx ID by hand; the
collision then fails loudly at the next apply.

## Identity

A least-privilege API user and token, created once by hand on the host:

```sh
pveum user add terraform@pve --comment "OpenTofu root terraform/proxmox (ADR-0011)"
pveum acl modify /vms --user terraform@pve --role PVEVMAdmin
pveum acl modify /storage --user terraform@pve --role PVEDatastoreUser
pveum acl modify /sdn/zones/localnetwork/vmbr0 --user terraform@pve --role PVESDNUser
pveum user token add terraform@pve terraform --privsep=0
```

`PVEVMAdmin` on `/vms` covers VM lifecycle and configuration, including
the cloud-init drive and the template flag; `PVEDatastoreUser` on
`/storage` covers disk allocation on `local-lvm`. `PVESDNUser` on the
`vmbr0` bridge grants `SDN.Use`, which PVE 9 requires to attach a NIC to
a bridge — without it the VM create fails with `Permission check failed
(/sdn/zones/localnetwork/vmbr0, SDN.Use)`. Nothing else is granted — in
particular, not `Administrator`.

`pveum user token add` prints the secret exactly once. Put the full token
(`terraform@pve!terraform=<uuid>`) in `terraform.tfvars`, which is
gitignored by the repo's `*.tfvars` rule and never committed:

```hcl
pve_api_token = "terraform@pve!terraform=<uuid>"
```

To rotate the token, remove and re-add it and update `terraform.tfvars`:

```sh
pveum user token remove terraform@pve terraform
pveum user token add terraform@pve terraform --privsep=0
```

Removing the identity entirely (after `tofu destroy`):

```sh
pveum user token remove terraform@pve terraform
pveum user delete terraform@pve
```

## Image source

The template imports the Debian 13 generic-cloud qcow2 already on the
host — `local:iso/debian-13-genericcloud-amd64.img`, i.e.
`/var/lib/vz/template/iso/` on datastore `local`. The file is a qcow2; it
carries the `.img` name because PVE's `dir` plugin cannot address a
`.qcow2` file as `iso` content (`pvesm path` fails with "unable to parse
directory volume name"), while it accepts `.img` and QEMU still detects
the real format. The provider's own cloud-image guide renames downloaded
qcow2 images to `*.img` for the same reason.

Because the file's content type is `iso`, not `import`, the provider
imports it over **SSH** (`qm importdisk`) rather than the API, so the
`ssh` block in `providers.tf` names the operator key explicitly — the
provider does not read `~/.ssh/config`, and API-token auth gives it no
password to reuse. If your key is not `~/.ssh/id_ed25519`, override
`pve_ssh_private_key_path`. No download is managed by this root: if newer
image bytes replace the file, `tofu destroy` and re-apply to rebuild the
template from them.

## Usage

```sh
tofu init     # providers + GCS backend (rockingham-homelab-tfstate, prefix terraform/proxmox)
tofu plan     # run from a workstation with LAN access — there is no CI path (ADR-0011)
tofu apply
```

`terraform.tfvars` carries only the API token; every other variable has a
default (endpoint `https://192.168.1.248:8006/`, node `pve`, VM ID 200).

## Cloning the template

A future durable VM becomes a resource in this root with a `clone` block
and its own `initialization` for identity:

```hcl
resource "proxmox_virtual_environment_vm" "builder_01" {
  name      = "builder-01"
  node_name = var.pve_node_name
  vm_id     = 201

  clone {
    vm_id = proxmox_virtual_environment_vm.debian_13_template.vm_id
    full  = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.1.240/24"
        gateway = "192.168.1.1"
      }
    }

    user_account {
      username = "jack"
      keys     = [trimspace(file("~/.ssh/id_ed25519.pub"))]
    }
  }
}
```

`tofu apply` clones the template and cloud-init gives the clone its user,
key, and address on first boot. Pick an address outside the DHCP scope;
the template itself has no fixed IP and no baked-in identity.
