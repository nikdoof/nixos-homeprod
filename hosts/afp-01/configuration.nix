{
  inputs,
  config,
  lib,
  mkMAC,
  pkgs,
  ...
}:
let
  hostName = "afp-01";
  domainName = "int.doofnet.uk";
  vlan = "101";
  mac = mkMAC hostName;
in
{
  imports = [
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
  networking.hostName = "afp-01";
  networking.domain = domainName;
  networking.search = [ domainName ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
  };

  doofnet.server = true;

  services.netatalk = {
    enable = true;

    settings = {
      Global = {
        appletalk = "yes";
        "uam list" = "uams_guest.so uams_dhx_pam.so uams_dhx2_pam.so uams_pam.so";
        "afpstats" = "yes";
        "vol dbpath" = "/persist/netatalk/cnid";
      };

      archive = {
        "volume name" = "Software Archive";
        path = "/persist/netatalk/shares/archive";
        ea = "sys";
        rolist = "nobody";
        rwlist = "nikdoof";
      };

      dropbox = {
        "volume name" = "Dropbox";
        path = "/persist/netatalk/shares/dropbox";
        ea = "sys";
      };

      transfer = {
        "volume name" = "Transfer";
        path = "/persist/netatalk/shares/transfer";
        ea = "sys";
        "valid users" = "nikdoof";
      };

      data = {
        "volume name" = "Data";
        path = "/persist/netatalk/shares/data";
        ea = "sys";
        rolist = "nobody";
      };
    };
  };
}
