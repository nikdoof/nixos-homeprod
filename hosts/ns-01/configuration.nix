{
  inputs,
  config,
  lib,
  ...
}:
let
  mkMac =
    seed:
    let
      hash = builtins.hashString "md5" seed;
      c = off: builtins.substring off 2 hash;
    in
    "${builtins.substring 0 1 hash}2:${c 2}:${c 4}:${c 6}:${c 8}:${c 10}";
  mac = mkMac config.networking.fqdn;
in
{
  imports = [
    # Include the results of the hardware scan.
    ../../modules/doofnet
    ../../modules/bind/primary.nix
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
        id = "vm-${config.networking.hostName}";
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
  networking.hostName = "ns-01";
  networking.nameservers = [
    "127.0.0.1"
  ];
  networking.domain = "int.doofnet.uk";
  networking.search = [ "int.doofnet.uk" ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [
        "10.101.1.2/16"
        "2001:8b0:bd9:101::2/64"
        "fddd:d00f:dab0:101::2/64"
      ];
      Gateway = "10.101.1.1";
      IPv6AcceptRA = true;
      DHCP = "no";
    };
  };

  doofnet.server = true;

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

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
