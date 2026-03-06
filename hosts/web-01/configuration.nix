{
  inputs,
  config,
  lib,
  mkMAC,
  pkgs,
  ...
}:
let
  hostName = "web-01";
  domainName = "doofnet.uk";
  vlan = "106";
  mac = mkMAC hostName;

  sites = [
    "${hostName}.${domainName}"
    "2315media.com"
    "bluecalx.co.uk"
    "doofnet.uk"
    "hereforthis.uk"
    "incognitus.net"
    "intellectops.com"
    "nikdoof.com"
    "oojamaflip.wtf"
    "parkpioneer.com"
    "parkpioneer.review.2315media.com"
  ];

  redirects = [
    {
      name = "${hostName}.${domainName}";
      target = "doofnet.uk";
    }
    {
      name = "thatgirl.co.uk";
      target = "oojamaflip.wtf";
    }
    {
      name = "alanthetravellingalpaca.com";
      target = "oojamaflip.wtf";
    }
    {
      name = "joslittlecorner.co.uk";
      target = "oojamaflip.wtf";
    }
    {
      name = "joslittlecorner.com";
      target = "oojamaflip.wtf";
    }
    {
      name = "nikdoof.id";
      target = "nikdoof.com";
    }
    {
      name = "andrewwilliams.net";
      target = "nikdoof.com";
    }
    {
      name = "andrew.williams.id";
      target = "nikdoof.com";
    }
  ];

  # Build the nginx vHost config using common params
  nginx_sites = lib.listToAttrs (
    lib.mapAttrsToList
      (name: site: {
        name = name;
        value = {
          enableACME = true;
          forceSSL = true;
          root = "/persist/sites/${name}";
        };
      })
      (
        lib.listToAttrs (
          lib.map (name: {
            name = name;
            value = name;
          }) sites
        )
      )
  );

  nginx_sites_redirects = lib.listToAttrs (
    lib.mapAttrsToList
      (name: redirect: {
        name = name;
        value = {
          enableACME = true;
          forceSSL = true;
          locations."/".extraConfig = ''
            return 301 https://${redirect.target}$request_uri;
          '';
        };
      })
      (
        lib.listToAttrs (
          lib.map (redirect: {
            name = redirect.name;
            value = redirect;
          }) redirects
        )
      )
  );

  # Take the root of each site and create a tmpfiles rule
  nginx_site_folders = lib.concatMap (site: [
    "d /persist/sites/${site} 0755 deploy deploy -"
  ]) sites;
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
    "217.169.20.20"
    "217.169.20.21"
    "2001:8b0::2020"
    "2001:8b0::2021"
  ];
  networking.domain = domainName;
  networking.search = [ domainName ];
  systemd.network.enable = true;

  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [
        "217.169.25.10/29"
        "2001:8b0:bd9:106::2/64"
      ];
      Gateway = "217.169.25.9";
      IPv6AcceptRA = true;
      DHCP = "no";
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      80
      443
    ];
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

  # Persist the ACME folder
  fileSystems."/var/lib/acme" = {
    device = "/persist/acme";
    options = [ "bind" ];
  };

  users = {
    groups.deploy = { };
    users.deploy = {
      group = "deploy";
      shell = pkgs.zsh;
      isSystemUser = true;
      home = "/persist/sites";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPnOF7hixCwjxvN9dpmOIXIdJSSiMLNeur6u+iG3HWM github-deploy"
      ];
    };
  };

  doofnet.server = true;

  services.nginx = {
    enable = true;

    virtualHosts = nginx_sites // nginx_sites_redirects;
  };

  # Create the deployment folders
  systemd.tmpfiles.rules = nginx_site_folders;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
