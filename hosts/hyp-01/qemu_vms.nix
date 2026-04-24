{
  pkgs,
  lib,
  ...
}:
let
  ovmf = pkgs.OVMF.fd;
  dataDir = "/srv/data/vms";

  # VM definitions.
  # Required: vlans (list of VLAN ID strings — one NIC per VLAN, in order)
  # Optional: mac (override the base MAC used for the first NIC; additional
  #           NICs derive a per-VLAN MAC from name+vlan),
  #           tapId (derived from name), vcpus (2), memory (2048),
  #           diskFormat ("vmdk")
  # Disk image is always at /srv/data/vms/<name>/disk.<diskFormat>
  vms = {
    homeassistant = {
      vlans = [
        "101"
        "105"
      ];
      tapId = "ha";
    };
  };

  # Apply defaults and derive any unset fields from the VM name
  normaliseVm = name: vm: {
    inherit (vm) vlans;
    mac = vm.mac or (lib.mkMAC name);
    tapId = vm.tapId or (builtins.substring 0 8 name);
    vcpus = vm.vcpus or 2;
    memory = vm.memory or 2048;
    diskFormat = vm.diskFormat or "vmdk";
  };

  # One NIC descriptor per VLAN. The first NIC keeps the VM-level MAC so
  # single-VLAN VMs preserve their existing DHCP lease on migration;
  # additional NICs derive a per-VLAN MAC from name+vlan.
  mkNics =
    name: normVm:
    lib.imap0 (i: vlan: {
      inherit vlan;
      tap = "vm-${vlan}-${normVm.tapId}";
      mac = if i == 0 then normVm.mac else lib.mkMAC "${name}-${vlan}";
      netId = "net${toString i}";
    }) normVm.vlans;

  mkQemuService =
    name: vm:
    let
      normVm = normaliseVm name vm;
      nics = mkNics name normVm;
      vmDir = "${dataDir}/${name}";
      varsFile = "${vmDir}/OVMF_VARS.fd";
      diskFile = "${vmDir}/disk.${normVm.diskFormat}";

      tapAddCommands = lib.concatMap (n: [
        "+${pkgs.iproute2}/bin/ip tuntap add dev ${n.tap} mode tap"
        "+${pkgs.iproute2}/bin/ip link set ${n.tap} up"
      ]) nics;

      tapDelCommands = map (
        n: "+${pkgs.bash}/bin/bash -c '${pkgs.iproute2}/bin/ip link del ${n.tap} || true'"
      ) nics;

      netArgs = lib.concatMap (n: [
        "-netdev"
        "tap,id=${n.netId},ifname=${n.tap},script=no,downscript=no,vhost=on"
        "-device"
        "virtio-net-pci,netdev=${n.netId},mac=${n.mac}"
      ]) nics;
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

        ExecStartPre = tapAddCommands ++ [
          # Seed a writable EFI vars store on first boot
          "${pkgs.bash}/bin/bash -c 'test -f ${varsFile} || cp ${ovmf}/FV/OVMF_VARS.fd ${varsFile}'"
        ];
        ExecStopPost = tapDelCommands;

        ExecStart = lib.escapeShellArgs (
          [
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
          ]
          ++ netArgs
          ++ [
            # Serial console on a Unix socket; output also logged to console.log
            "-chardev"
            "socket,id=con,path=${vmDir}/console.sock,server=on,wait=off,logfile=${vmDir}/console.log"
            "-serial"
            "chardev:con"
            # QEMU monitor on a Unix socket
            "-chardev"
            "socket,id=mon,path=${vmDir}/monitor.sock,server=on,wait=off"
            "-mon"
            "chardev=mon,mode=readline"
            "-nographic"
            "-nodefaults"
          ]
        );

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
  vmNames = builtins.attrNames vms;

  qemuConsole = pkgs.writeShellApplication {
    name = "qemu-console";
    runtimeInputs = [
      pkgs.socat
      pkgs.systemd
    ];
    text = ''
      valid_vms=(${lib.concatStringsSep " " vmNames})

      usage() {
        echo "Usage: qemu-console <vm-name>"
        echo ""
        echo "Available VMs: ''${valid_vms[*]}"
      }

      if [ $# -eq 0 ]; then
        echo "QEMU VMs:"
        for vm in "''${valid_vms[@]}"; do
          if systemctl is-active --quiet "qemu-vm-$vm" 2>/dev/null; then
            status="running"
          else
            status="stopped"
          fi
          printf "  %-20s %s\n" "$vm" "$status"
        done
        exit 0
      fi

      vm="$1"

      valid=0
      for v in "''${valid_vms[@]}"; do
        if [ "$v" = "$vm" ]; then
          valid=1
          break
        fi
      done

      if [ "$valid" -eq 0 ]; then
        echo "error: unknown VM '$vm'" >&2
        usage >&2
        exit 1
      fi

      sock="${dataDir}/$vm/console.sock"

      if [ ! -S "$sock" ]; then
        echo "error: '$vm' is not running (console socket not found)" >&2
        exit 1
      fi

      echo "Connecting to $vm console... (press Ctrl-] to disconnect)"
      exec socat -,raw,echo=0,escape=0x1d "UNIX-CONNECT:$sock"
    '';
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

  # Allow nikdoof to access VM sockets without sudo
  users.users.nikdoof.extraGroups = [ "qemu-vm" ];

  systemd.tmpfiles.rules = lib.concatMap (name: [
    "d ${dataDir}/${name} 0750 qemu-vm qemu-vm -"
  ]) (builtins.attrNames vms);

  environment.systemPackages = [ qemuConsole ];

  systemd.services = lib.mapAttrs' (
    name: vm: lib.nameValuePair "qemu-vm-${name}" (mkQemuService name vm)
  ) vms;
}
