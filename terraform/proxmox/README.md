# terraform/proxmox

Manages durable VMs on the utility host `pve.home.arpa` (Proxmox VE 9.2.x,
`192.168.1.248`) — the lab's non-cluster compute component ([ADR-0011](../../docs/adr/0011-utility-host.md)).
Today it owns two resources: the **Debian 13 cloud-image template** that
durable utility VMs clone, and **`buildkit-01`**, the first tenant — a
BuildKit builder for LAN clients
([#253](https://github.com/jvcorredor/homelab/issues/253)).

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
pveum acl modify /storage/local --user terraform@pve --role PVEDatastoreAdmin
pveum acl modify /sdn/zones/localnetwork/vmbr0 --user terraform@pve --role PVESDNUser
pveum user token add terraform@pve terraform --privsep=0
```

`PVEVMAdmin` on `/vms` covers VM lifecycle and configuration, including
the cloud-init drive and the template flag; `PVEDatastoreUser` on
`/storage` covers disk allocation on `local-lvm`. `PVEDatastoreAdmin` on
`/storage/local` is scoped to the one datastore and is what the snippet
upload for `buildkit-01` checks (`Datastore.Allocate` there; the
`PVEDatastoreUser` role does not include it). `PVESDNUser` on the
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

## Snippets

`buildkit-01`'s cloud-init provisioning is uploaded to the `local`
datastore as a **snippet**, and PVE does not allow `snippets` content on a
datastore by default. Enable it once, on the host — in the UI
(Datacenter → Storage → `local` → Edit → Content) or:

```sh
pvesm set local --content iso,vztmpl,backup,import,snippets
```

Name every content type the datastore should keep: the flag replaces the
set (this host also allows `import`, so it must be listed).

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

## buildkit-01

The first durable tenant: a 4 vCPU · 8 GB RAM · 64 GB clone of the
template at `192.168.1.249`, running `buildkitd` for LAN clients
([#253](https://github.com/jvcorredor/homelab/issues/253)).

- It listens on `tcp://0.0.0.0:1234` with **mutual TLS**: only clients
  holding a certificate signed by its CA can connect, and the client
  verifies the daemon with the same CA. The client bundle lives on the VM
  at `/home/jack/buildkit-client/`; fetch it once:

  ```sh
  scp -r jack@192.168.1.249:/home/jack/buildkit-client ~/.config/buildkit/
  ```

- Then drive it directly:

  ```sh
  buildctl --addr tcp://192.168.1.249:1234 \
    --tlscacert ~/.config/buildkit/buildkit-client/ca.crt \
    --tlscert ~/.config/buildkit/buildkit-client/client.crt \
    --tlskey ~/.config/buildkit/buildkit-client/client.key \
    debug workers
  ```

  or register it as a buildx builder:

  ```sh
  docker buildx create --name buildkit-01 --driver remote \
    --addr tcp://192.168.1.249:1234 \
    --tlscacert ~/.config/buildkit/buildkit-client/ca.crt \
    --tlscert ~/.config/buildkit/buildkit-client/client.crt \
    --tlskey ~/.config/buildkit/buildkit-client/client.key
  ```

- Provisioning is [`files/buildkit-01-vendor-data.yaml`](./files/buildkit-01-vendor-data.yaml),
  passed as cloud-init vendor-data. It installs a pinned, checksum-verified
  BuildKit release, generates all TLS material on the VM, and starts
  `buildkitd`. The CA key never leaves the VM; no key is committed or
  stored in state.
- The script runs at first boot only. To bump the BuildKit pin, change the
  file and either re-run `/usr/local/bin/provision-buildkit.sh` on the VM
  or destroy and re-apply it.
- Rebuilding the VM regenerates the CA, so the client bundle must be
  fetched again.
- The same LAN listener is what future ARC runners will use; no tunnel is
  involved.

## Cloning the template

A durable VM becomes a resource in this root with a `clone` block and its
own `initialization` for identity. [`buildkit.tf`](./buildkit.tf) is the
live example; the shape is:

```hcl
resource "proxmox_virtual_environment_vm" "example_vm" {
  name      = "example-vm"
  node_name = var.pve_node_name
  vm_id     = 202

  clone {
    vm_id = proxmox_virtual_environment_vm.debian_13_template.vm_id
    full  = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.1.250/24"
        gateway = "192.168.1.1"
      }
    }

    user_account {
      username = "jack"
      keys     = [trimspace(file(pathexpand(var.vm_ssh_public_key_path)))]
    }
  }
}
```

`tofu apply` clones the template and cloud-init gives the clone its user,
key, and address on first boot. The template itself has no fixed IP and no
baked-in identity, so every clone picks an address: the Optimum DHCP scope
is `.11-.199`, the Cilium LB pool is `.200-.230`, the cluster and pve hold
`.240-.248`, and `buildkit-01` takes `.249` — `.244` and `.250-.254` are
free. `file()` does not expand `~`, so public keys go through
`pathexpand`, as in `buildkit.tf`.
