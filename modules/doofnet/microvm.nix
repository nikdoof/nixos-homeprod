{
  config,
  lib,
  ...
}:
let
  cfg = config.doofnet.microvm;
in
{
  options.doofnet.microvm = {
    enable = lib.mkEnableOption "doofnet microVM guest configuration";

    cid = lib.mkOption {
      type = lib.types.int;
      description = "vsock context identifier (CID) for this VM. Must be unique across all VMs on the host.";
      example = 11;
    };

    vlan = lib.mkOption {
      type = lib.types.str;
      description = "VLAN number used to name the tap interface (e.g. \"101\" produces tap id \"vm-101-<hostname>\").";
      example = "101";
    };

    mac = lib.mkOption {
      type = lib.types.str;
      description = "MAC address for the VM's tap interface. Defaults to a deterministic address derived from the hostname.";
      default = lib.mkMAC config.networking.hostName;
      defaultText = lib.literalExpression "lib.mkMAC config.networking.hostName";
    };

    vcpu = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Number of virtual CPUs to allocate to this VM.";
      example = 4;
    };

    mem = lib.mkOption {
      type = lib.types.int;
      default = 1024;
      description = "Amount of memory in MiB to allocate to this VM.";
      example = 2048;
    };
  };

  config = lib.mkIf cfg.enable {
    microvm = {
      hypervisor = "qemu";
      inherit (cfg) vcpu mem;

      registerWithMachined = true;
      vsock.ssh.enable = true;
      vsock.cid = cfg.cid;

      interfaces = [
        {
          type = "tap";
          tap.vhost = true;
          id = "vm-${cfg.vlan}-${config.networking.hostName}";
          inherit (cfg) mac;
        }
      ];

      shares = [
        {
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
          tag = "ro-store";
          proto = "virtiofs";
        }
        {
          tag = "persist";
          source = "/srv/data/persist/microvms/${config.networking.hostName}";
          mountPoint = "/persist";
          proto = "virtiofs";
        }
      ];
    };

    # Persist SSH host keys to the persistent share so they survive rebuilds.
    fileSystems."/persist".neededForBoot = lib.mkForce true;
    services.openssh.hostKeys = [
      {
        path = "/persist/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/persist/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];

    # Persist DHE params — prevents regeneration on every boot
    fileSystems."/var/lib/dhparams" = {
      device = "/persist/dhparams";
      options = [ "bind" ];
    };
  };
}
