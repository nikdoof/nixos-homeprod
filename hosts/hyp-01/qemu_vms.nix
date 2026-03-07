{
  pkgs,
  lib,
  mkMAC,
  ...
}:
let
  # VM definitions — add entries here to define more QEMU VMs.
  # Disk images live at /srv/data/vms/<name>/ on the host.
  # QEMU reads VMDK natively; to convert to qcow2 for better performance:
  #   qemu-img convert -f vmdk -O qcow2 disk.vmdk disk.qcow2
  vms = {
    homeassistant = {
      # MAC address derived deterministically from the VM name
      mac = mkMAC "homeassistant";
      vlan = "101";
      # Short tap interface ID — must produce an ifname under 15 chars
      # (Linux IFNAMSIZ limit). Format: vm-<vlan>-<tapId>
      tapId = "ha";
      # vCPU count
      vcpus = 2;
      # RAM in MiB
      memory = 2048;
      # Absolute path to the disk image on the host
      disk = "/srv/data/vms/homeassistant/disk.vmdk";
      diskFormat = "vmdk";
    };
  };

  mkQemuService =
    name: vm:
    let
      tapIface = "vm-${vm.vlan}-${vm.tapId}";
    in
    {
      description = "QEMU VM: ${name}";
      after = [
        "network-online.target"
        "sys-subsystem-net-devices-br0.device"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "5s";
        User = "qemu-vm";
        Group = "qemu-vm";

        # Tap interface lifecycle — run as root via the + prefix
        ExecStartPre = [
          "+${pkgs.iproute2}/bin/ip tuntap add dev ${tapIface} mode tap"
          "+${pkgs.iproute2}/bin/ip link set ${tapIface} up"
        ];
        ExecStopPost = [
          "+${pkgs.bash}/bin/bash -c '${pkgs.iproute2}/bin/ip link del ${tapIface} || true'"
        ];

        ExecStart = lib.escapeShellArgs [
          "${pkgs.qemu}/bin/qemu-system-x86_64"
          "-name"
          name
          "-machine"
          "type=q35,accel=kvm"
          "-cpu"
          "host"
          "-smp"
          (toString vm.vcpus)
          "-m"
          (toString vm.memory)
          "-drive"
          "file=${vm.disk},format=${vm.diskFormat},if=virtio,cache=writeback"
          "-netdev"
          "tap,id=net0,ifname=${tapIface},script=no,downscript=no,vhost=on"
          "-device"
          "virtio-net-pci,netdev=net0,mac=${vm.mac}"
          "-chardev"
          "stdio,id=con,mux=on,signal=off"
          "-serial"
          "chardev:con"
          "-mon"
          "chardev=con"
          "-nographic"
          "-nodefaults"
        ];

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/srv/data/vms/${name}" ];
        DeviceAllow = [
          "/dev/kvm rw"
          "/dev/net/tun rw"
          "/dev/vhost-net rw"
        ];
      };
    };
in
{
  # Unprivileged user that owns the QEMU processes
  users.users.qemu-vm = {
    isSystemUser = true;
    group = "qemu-vm";
    extraGroups = [ "kvm" ];
    description = "QEMU VM runner";
  };
  users.groups.qemu-vm = { };

  # Ensure VM disk directories exist on the persistent volume
  systemd.tmpfiles.rules = lib.concatMap (name: [
    "d /srv/data/vms/${name} 0750 qemu-vm qemu-vm -"
  ]) (builtins.attrNames vms);

  # One systemd service per VM
  systemd.services = lib.mapAttrs' (
    name: vm: lib.nameValuePair "qemu-vm-${name}" (mkQemuService name vm)
  ) vms;
}
