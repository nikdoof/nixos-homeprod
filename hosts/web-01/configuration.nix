{
  lib,
  pkgs,
  ...
}:
let
  hostName = "web-01";
  domainName = "doofnet.uk";

  sites = [
    "${hostName}.${domainName}"
    "2315media.com"
    "bluecalx.co.uk"
    "dimension.sh"
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
      (name: _: {
        inherit name;
        value = {
          enableACME = true;
          forceSSL = true;
          root = "/persist/sites/${name}";
          extraConfig = ''
            access_log /var/log/nginx/access.log combined;
            log_not_found off;
            add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
            add_header X-Content-Type-Options "nosniff" always;
            add_header X-Frame-Options "SAMEORIGIN" always;
            add_header Referrer-Policy "strict-origin-when-cross-origin" always;
            add_header X-XSS-Protection "0" always;
          '';
        };
      })
      (
        lib.listToAttrs (
          lib.map (name: {
            inherit name;
            value = name;
          }) sites
        )
      )
  );

  nginx_sites_redirects = lib.listToAttrs (
    lib.mapAttrsToList
      (name: redirect: {
        inherit name;
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
            inherit (redirect) name;
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
  doofnet.microvm = {
    enable = true;
    cid = 14;
    vlan = "106";
  };

  # Networking
  networking.useDHCP = false;
  networking.hostName = hostName;
  networking.nameservers = [
    "217.169.25.9"
    "2001:8b0:bd9:106::1"
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

  # Persist the ACME folder
  fileSystems."/var/lib/acme" = {
    device = "/persist/acme";
    options = [ "bind" ];
  };

  users = {
    groups.deploy = { };
    users.deploy = {
      group = "deploy";
      shell = pkgs.shadow;
      isSystemUser = true;
      home = "/persist/sites";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGPnOF7hixCwjxvN9dpmOIXIdJSSiMLNeur6u+iG3HWM github-deploy"
      ];
    };
  };

  # Restrict the deploy user to rsync transfers into /persist/sites only
  services.openssh.extraConfig = ''
    Match User deploy
      ForceCommand ${pkgs.rsync}/bin/rrsync /persist/sites
      AllowTcpForwarding no
      X11Forwarding no
      PermitTTY no
  '';

  doofnet.server = true;

  environment.etc."alloy/conf.d/01-nginx.alloy".text = ''
    local.file_match "nginx" {
      path_targets = [{"__path__" = "/var/log/nginx/*.log", "job" = "nginx", "host" = "${hostName}"}]
      sync_period  = "5s"
    }

    loki.source.file "nginx" {
      targets    = local.file_match.nginx.targets
      forward_to = [loki.write.default.receiver]
    }
  '';

  # Alloy runs as a DynamicUser; nginx group grants read access to /var/log/nginx/.
  # Lists are used so NixOS merges these with any other module (e.g. traefik.nix) that
  # also adds to SupplementaryGroups/ReadOnlyPaths for the alloy service.
  systemd.services.alloy.serviceConfig.SupplementaryGroups = [ "nginx" ];
  systemd.services.alloy.serviceConfig.ReadOnlyPaths = [ "/var/log/nginx" ];

  services.nginx = {
    enable = true;
    statusPage = true;
    serverTokens = false;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    appendHttpConfig = ''
      client_max_body_size 64k;
    '';

    virtualHosts = nginx_sites // nginx_sites_redirects;
  };

  services.prometheus.exporters.nginx = {
    enable = true;
    port = 9113;
    listenAddress = "127.0.0.1";
    scrapeUri = "http://127.0.0.1/nginx_status";
  };

  environment.etc."alloy/conf.d/02-nginx.alloy".text = ''
    prometheus.scrape "nginx" {
      targets    = [{"__address__" = "localhost:9113"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "nginx"
    }
  '';

  # Create the deployment folders
  systemd.tmpfiles.rules = nginx_site_folders;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
