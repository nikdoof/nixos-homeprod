{
  inputs,
  config,
  lib,
  mkMAC,
  ...
}:
let
  hostName = "ns-02";
  domainName = "int.doofnet.uk";
  vlan = "101";
  mac = mkMAC hostName;
in
{
  imports = [
    # Include the results of the hardware scan.
    ../../modules/doofnet
    inputs.microvm.nixosModules.microvm
  ];

  microvm = {
    hypervisor = "qemu";
    vcpu = 2;
    mem = 1024;
    interfaces = [
      {
        type = "tap";
        tap.vhost = true;
        id = "vm-${vlan}-${hostName}";
        inherit mac;
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

  # Networking
  networking.useDHCP = false;
  networking.hostName = hostName;
  networking.nameservers = [
    "127.0.0.1"
    "10.101.1.2"
    "10.101.1.3"
  ];
  networking.domain = domainName;
  networking.search = [ domainName ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [
        "10.101.1.3/16"
        "2001:8b0:bd9:101::3/64"
        "fddd:d00f:dab0:101::3/64"
      ];
      Gateway = "10.101.1.1";
      IPv6AcceptRA = true;
      DHCP = "no";
    };
  };

  # Persist host key to persistant fs
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

  doofnet.server = true;

  doofnet.bind = {
    enable = true;
    mode = "secondary";
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
