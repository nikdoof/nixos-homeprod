{
  inputs,
  config,
  lib,
  mkMAC,
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
    "andrewwilliams.net"
    "alanthetravellingalpaca.com"
    "andrew.williams.id"
    "bluecalx.co.uk"
    "doofnet.uk"
    "hereforthis.uk"
    "incognitus.net"
    "intellectops.com"
    "joslittlecorner.com"
    "joslittlecorner.co.uk"
    "nikdoof.com"
    "nikdoof.id"
    "oojamaflip.wtf"
    "parkpioneer.com"
    "parkpioneer.review.2315media.com"
    "thatgirl.co.uk"
  ];

  redirects = [
    {
      name = "${hostName}.${domainName}";
      target = "doofnet.uk";
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
            value = redirect.target;
          }) redirects
        )
      )
  );
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

  services.nginx = {
    enable = true;

    virtualHosts = nginx_sites ++ nginx_sites_redirects;
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
