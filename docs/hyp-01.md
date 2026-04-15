# hyp-01: Hypervisor

hyp-01 is a KVM-based hypervisor running NixOS. It hosts two categories of virtual machine:
NixOS **microVMs** (declared in the flake, managed by the `microvm.nix` NixOS module), and
**QEMU VMs** (raw disk images, managed as plain systemd services). Both types share the same
bridge-based VLAN network.

## Hardware

HP Prodesk 600 G3 DM, same hardware class as the other base hosts. See `docs/base_host.md`.

## Networking

hyp-01 uses a single bridge (`br0`) with VLAN filtering. The physical uplink (`eno1`) is a
member of the bridge, carrying all VLANs as tagged traffic. Two VLANs are active:

| VLAN | Name     | Subnet             | IPv6 prefix               | Purpose                             |
|------|----------|--------------------|---------------------------|-------------------------------------|
| 101  | private  | 10.101.0.0/16      | 2001:8b0:bd9:101::/64     | Internal services                   |
| 106  | hosted   | 217.169.25.8/29    | 2001:8b0:bd9:106::/64     | Internet-facing / externally routed |

hyp-01's own management address is `10.101.3.22/16` (VLAN 101).

VM tap interfaces are named `vm-<vlan>-<identifier>` (e.g. `vm-101-afp-01`). Interfaces
matching `vm-101-*` are added to the bridge with PVID 101 (untagged egress on VLAN 101),
and `vm-106-*` likewise for VLAN 106. VMs therefore receive untagged Ethernet and see their
VLAN as a plain L2 segment.

IP forwarding is enabled for both IPv4 and IPv6 so the host can forward packets between its
interface and any routed subnets.

## MicroVMs

MicroVMs are NixOS guests declared in the main flake and evaluated as full NixOS
configurations. They run under the [`microvm.nix`](https://github.com/astro/microvm.nix)
NixOS module using QEMU as the hypervisor.

### Host-side configuration (`hosts/hyp-01/microvms.nix`)

Each guest is registered with `microvm.vms.<name>` pointing at the flake. Setting
`restartIfChanged = true` causes `nixos-rebuild` on the host to restart a guest when its
configuration changes.

At evaluation time the file cross-references every guest's evaluated NixOS configuration
(via `inputs.self.nixosConfigurations`) to extract its `doofnet.microvm.cid` value. A
NixOS assertion fires if any two guests share a CID, catching conflicts before deployment.

Persistent data directories are created under `/srv/data/persist/microvms/<name>` by
`systemd.tmpfiles`, and the entire tree is included in borgmatic backups.

### Guest-side module (`modules/doofnet/microvm.nix`)

Each guest enables `doofnet.microvm` and sets:

| Option | Type   | Default              | Description                                      |
|--------|--------|----------------------|--------------------------------------------------|
| `cid`  | int    | *(required)*         | vsock context ID, must be unique across all VMs  |
| `vlan` | string | *(required)*         | VLAN number used in the tap interface name        |
| `mac`  | string | `lib.mkMAC hostname` | MAC address for the tap interface                |
| `vcpu` | int    | `2`                  | Virtual CPU count                                |
| `mem`  | int    | `1024`               | Memory in MiB                                    |

The module configures the microvm with:

- **Hypervisor**: QEMU with KVM acceleration
- **vsock**: enabled with SSH access via `vsock.ssh.enable`; `registerWithMachined = true`
  so the guest appears in `machinectl`
- **Network**: single TAP interface (`vm-<vlan>-<hostname>`) with vhost acceleration
- **Shares** (virtiofs):
  - `/nix/.ro-store` ← `/nix/store` (read-only, shared from host)
  - `/persist` ← `/srv/data/persist/microvms/<hostname>` (writable, per-guest)
- **Persistence**: SSH host keys, DH parameters, and ACME certificates are stored under
  `/persist` so they survive NixOS rebuilds

### MAC address derivation (`lib/mkmac.nix`)

When no explicit MAC is provided, `lib.mkMAC hostname` generates a deterministic address:

1. SHA1 hash of the hostname is computed
2. Bytes 1–3 of the hash become the last three octets
3. The prefix `02:00:00` is prepended (locally administered, unicast)

This ensures stable MACs without manual assignment.

### Declared microVMs

| Name   | CID | VLAN | Role                                    |
|--------|-----|------|-----------------------------------------|
| afp-01 | 11  | 101  | AFP/AppleTalk file server, Netatalk     |
| ns-02  | 13  | 101  | Secondary DNS (BIND)                    |
| hs-01  | 10  | 106  | Headscale VPN controller, DERP server   |
| web-01 | 14  | 106  | Nginx web hosting (multiple domains)    |
| mx-01  | 12  | 106  | Mail server (Postfix + Dovecot + DKIM)  |
| grf-01 | 15  | 101  | Grafana monitoring dashboard            |

All guests use the default resource allocation (2 vCPUs, 1024 MiB RAM).

Guests on VLAN 106 (hs-01, web-01, mx-01) are internet-facing and have public IP addresses
in the 217.169.25.8/29 block.

## QEMU VMs

QEMU VMs are raw disk image guests that are not NixOS — they run arbitrary operating systems.
They are declared in `hosts/hyp-01/qemu_vms.nix` and each become a `qemu-vm-<name>` systemd
service.

### VM definition format

VMs are declared in the `vms` attrset. Required and optional fields:

| Field        | Required | Default                 | Description                              |
|--------------|----------|-------------------------|------------------------------------------|
| `vlan`       | yes      | —                       | VLAN number for network placement        |
| `mac`        | no       | `lib.mkMAC name`        | MAC address                              |
| `tapId`      | no       | first 8 chars of name   | Suffix of the tap interface name         |
| `vcpus`      | no       | `2`                     | Virtual CPU count                        |
| `memory`     | no       | `2048`                  | Memory in MiB                            |
| `diskFormat` | no       | `"vmdk"`                | QEMU disk image format                   |

Disk image path: `/srv/data/vms/<name>/disk.<diskFormat>`

EFI vars are seeded from the system OVMF package on first boot and stored per-VM at
`/srv/data/vms/<name>/OVMF_VARS.fd`, so EFI settings persist across reboots.

### Networking

Each VM gets a TAP interface named `vm-<vlan>-<tapId>`. The interface is created in
`ExecStartPre` (running as root via the `+` prefix) and destroyed in `ExecStopPost`.
Because the interface name follows the `vm-<vlan>-*` pattern it is automatically picked up
by the systemd-networkd match rules and placed onto the correct VLAN.

### Security

The `qemu-vm` system user and group own all VM processes. The service applies:

- `NoNewPrivileges = true`
- `PrivateTmp = true`
- `ProtectSystem = strict`
- `ReadWritePaths` limited to the VM's data directory
- `DeviceAllow` for `/dev/kvm`, `/dev/net/tun`, `/dev/vhost-net`

### Declared QEMU VMs

| Name          | VLAN | Notes                            |
|---------------|------|----------------------------------|
| homeassistant | 101  | Home Assistant OS image (VMDK)   |

## Storage layout

```
/srv/data/
  microvm/          → bind-mounted to /var/lib/microvm (microvm.nix state)
  persist/
    microvms/
      <name>/       → virtiofs "persist" share for each microVM
        ssh_host_ed25519_key
        ssh_host_rsa_key
        dhparams/
        acme/
  vms/
    <name>/         → data directory for each QEMU VM
      disk.<fmt>    → primary disk image
      OVMF_VARS.fd  → per-VM EFI variable store
```

## Adding a new microVM

1. Create `hosts/<name>/configuration.nix` with `doofnet.microvm.enable = true`, setting a
   unique `cid`, the desired `vlan`, and resource options.
2. Declare the guest in `flake.nix` using `mkMicrovm`:
   ```nix
   <name> = mkMicrovm "<name>" { };
   ```
   The `mkMicrovm` helper automatically adds `inputs.microvm.nixosModules.microvm` and
   `modules/doofnet/microvm.nix`. Pass `extraModules` if the guest needs additional modules.
3. Add `<name> = { flake = inputs.self; restartIfChanged = true; }` to `microvm.vms` in
   `hosts/hyp-01/microvms.nix`. The CID uniqueness assertion will catch any conflicts at
   `nix flake check` time.

## Adding a new QEMU VM

1. Add an entry to the `vms` attrset in `hosts/hyp-01/qemu_vms.nix` with at minimum `vlan`
   set.
2. Place (or symlink) the disk image at `/srv/data/vms/<name>/disk.<diskFormat>`.
3. `nixos-rebuild switch` on hyp-01 will create the data directory, generate the tap
   interface config, and start the `qemu-vm-<name>` service.
