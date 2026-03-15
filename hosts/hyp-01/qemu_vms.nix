{
  pkgs,
  lib,
  ...
}:
let
  ovmf = pkgs.OVMF.fd;
  dataDir = "/srv/data/vms";

  # VM definitions.
  # Required: vlan
  # Optional: mac (derived from name), tapId (derived from name),
  #           vcpus (2), memory (2048), diskFormat ("vmdk")
  # Disk image is always at /srv/data/vms/<name>/disk.<diskFormat>
  vms = {
    homeassistant = {
      vlan = "101";
      tapId = "ha";
    };
  };

  # Apply defaults and derive any unset fields from the VM name
  normaliseVm = name: vm: {
    mac = vm.mac or (lib.mkMAC name);
    inherit (vm) vlan;
    tapId = vm.tapId or (builtins.substring 0 8 name);
    vcpus = vm.vcpus or 2;
    memory = vm.memory or 2048;
    diskFormat = vm.diskFormat or "vmdk";
  };

  mkQemuService =
    name: vm:
    let
      normVm = normaliseVm name vm;
      tapIface = "vm-${normVm.vlan}-${normVm.tapId}";
      vmDir = "${dataDir}/${name}";
      varsFile = "${vmDir}/OVMF_VARS.fd";
      diskFile = "${vmDir}/disk.${normVm.diskFormat}";
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

        ExecStartPre = [
          # Tap interface setup — runs as root
          "+${pkgs.iproute2}/bin/ip tuntap add dev ${tapIface} mode tap"
          "+${pkgs.iproute2}/bin/ip link set ${tapIface} up"
          # Seed a writable EFI vars store on first boot
          "${pkgs.bash}/bin/bash -c 'test -f ${varsFile} || cp ${ovmf}/FV/OVMF_VARS.fd ${varsFile}'"
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
          (toString normVm.vcpus)
          "-m"
          (toString normVm.memory)
          # EFI firmware: read-only code + writable per-VM vars
          "-drive"
          "if=pflash,format=raw,readonly=on,file=${ovmf}/FV/OVMF_CODE.fd"
          "-drive"
          "if=pflash,format=raw,file=${varsFile}"
          # Primary disk
          "-drive"
          "file=${diskFile},format=${normVm.diskFormat},if=virtio,cache=writeback"
          # Network
          "-netdev"
          "tap,id=net0,ifname=${tapIface},script=no,downscript=no,vhost=on"
          "-device"
          "virtio-net-pci,netdev=net0,mac=${normVm.mac}"
          # Serial console → journald via stdio
          "-chardev"
          "stdio,id=con,mux=on,signal=off"
          "-serial"
          "chardev:con"
          "-mon"
          "chardev=con"
          "-nographic"
          "-nodefaults"
        ];

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ vmDir ];
        DeviceAllow = [
          "/dev/kvm rw"
          "/dev/net/tun rw"
          "/dev/vhost-net rw"
        ];
      };
    };
in
{
  users.users.qemu-vm = {
    isSystemUser = true;
    group = "qemu-vm";
    extraGroups = [ "kvm" ];
    description = "QEMU VM runner";
  };
  users.groups.qemu-vm = { };

  systemd.tmpfiles.rules = lib.concatMap (name: [
    "d ${dataDir}/${name} 0750 qemu-vm qemu-vm -"
  ]) (builtins.attrNames vms);

  systemd.services = lib.mapAttrs' (
    name: vm: lib.nameValuePair "qemu-vm-${name}" (mkQemuService name vm)
  ) vms;
}
