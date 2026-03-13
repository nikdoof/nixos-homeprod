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

  papdConfig = pkgs.writeText "papd.conf" ''
    HP LaserJet 200 M251n:\
       :pr=HP_LaserJet_200_color_M251n_5F9EF6:op=root:
  '';
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

    registerWithMachined = true;
    vsock.ssh.enable = true;
    vsock.cid = 11;

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

  boot.kernelModules = [ "appletalk" ];

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
        "10.101.3.30/16"
        "2001:8b0:bd9:101::3:30/64"
        "fddd:d00f:dab0:101::3:30/64"
      ];
      Gateway = "10.101.1.1";
      IPv6AcceptRA = true;
      DHCP = "no";
      MulticastDNS = true;
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

  services.avahi = {
    enable = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  services.netatalk = {
    enable = true;

    settings = {
      Global = {
        appletalk = "yes";
        "uam list" = "uams_guest.so uams_dhx_pam.so uams_dhx2_pam.so uams_pam.so";
        "afpstats" = "yes";
        "vol dbpath" = "/persist/netatalk/cnid";
        "mimic model" = "RackMac";
        "map acls" = "mode";
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
        rwlist = "nobody nikdoof";
        ea = "sys";
      };

      transfer = {
        "volume name" = "Transfer";
        path = "/persist/netatalk/shares/transfer";
        ea = "sys";
        "valid users" = "nikdoof";
        rwlist = "nikdoof";
      };

      data = {
        "volume name" = "Data";
        path = "/persist/netatalk/shares/data";
        ea = "sys";
        rolist = "nobody";
        rwlist = "nikdoof";
      };
    };
  };

  services.globaltalk.scrape = {
    enable = true;
    outputFile = "/persist/netatalk/shares/data/globaltalk.json";
  };
  services.globaltalk.metrics.enable = true;

  networking.firewall = {
    allowedTCPPorts = [
      548 # AFP
    ];
  };

  # Override netatalk's spool path
  nixpkgs.overlays = [
    (_: super: {
      netatalk = super.netatalk.overrideAttrs (_: {
        version = "4.4.1";
        src = pkgs.fetchurl {
          url = "mirror://sourceforge/netatalk/netatalk/netatalk-4.4.1.tar.xz";
          hash = "sha256-j8qwvzs5zYqU/j7nqCZMYABRWjrzd9o0FmlmCasTMW0=";
        };
      });
    })
  ];

  systemd.services.netatalk = {
    after = [ "atalkd.service" ];
  };

  systemd.services.atalkd = {
    description = "Netatalk AppleTalk daemon";
    after = [
      "network.target"
    ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.netatalk ];

    serviceConfig = {
      Type = "forking";
      GuessMainPID = "no";
      PIDFile = "/run/lock/atalkd";
      ExecStart = "${pkgs.netatalk}/sbin/atalkd";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP  $MAINPID";
      ExecStop = "${pkgs.coreutils}/bin/kill -TERM $MAINPID";
      Restart = "always";
      RestartSec = 1;
    };
  };

  services.printing = {
    enable = true;
  };

  systemd.services.papd = {
    description = "Netatalk printing daemon";
    after = [
      "network.target"
      "atalkd.service"
    ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.netatalk ];

    serviceConfig = {
      Type = "forking";
      GuessMainPID = "no";
      PIDFile = "/run/lock/papd";
      ExecStart = "${pkgs.netatalk}/sbin/papd -f ${papdConfig}";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP  $MAINPID";
      ExecStop = "${pkgs.coreutils}/bin/kill -TERM $MAINPID";
      Restart = "always";
      RestartSec = 1;
    };
  };

  # Create the spool folder for netatalk/papd, and fixes NixOS oddities with papd
  systemd.tmpfiles.rules = [
    "d /var/spool/netatalk 0777 root root - -"
    "L /var/spool/netatalk/var/spool/netatalk - - - - /var/spool/netatalk"
  ];

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
