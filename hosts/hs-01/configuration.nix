{
  inputs,
  config,
  lib,
  mkMAC,
  ...
}:
let
  hostName = "hs-01";
  domainName = "doofnet.uk";
  vlan = "106";
  mac = mkMAC hostName;

  acl_config = {
    acls = [
      {
        action = "accept";
        src = [
          "group:home"
        ];
        dst = [
          "tag:home:*"
          "tag:vpn:*"
          "10.0.0.0/8:*"
          "2001:8b0:bd9::/48:*"
          "*:*"
        ];
      }
      {
        action = "accept";
        src = [
          "group:admin"
        ];
        dst = [
          "*:*"
        ];
      }
    ];
    groups = {
      "group:home" = [
        "andy@williams.id"
        "jo@williams.id"
      ];
      "group:vpn" = [
        "andy@williams.id"
        "jo@williams.id"
      ];
      "group:admin" = [
        "andy@williams.id"
      ];
    };
    tagOwners = {
      "tag:home" = [
        "andy@williams.id"
      ];
      "tag:vpn" = [
        "andy@williams.id"
      ];
      "tag:servers" = [
        "andy@williams.id"
      ];
    };
    ssh = [
      {
        action = "accept";
        src = [
          "group:admin"
        ];
        dst = [
          "tag:servers"
        ];
        users = [
          "ansible"
        ];
      }
    ];
  };
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
    "217.169.25.9"
    "217.169.20.20"
    "217.169.20.21"
    "2001:8b0::2020"
    "2001:8b0::2021"
  ];
  networking.domain = domainName;
  networking.search = [ domainName ];
  networking.hosts = {
    "10.101.3.20" = [ "id.doofnet.uk" ];
  };
  systemd.network.enable = true;

  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [
        "217.169.25.13/29"
        "2001:8b0:bd9:106::13/64"
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

  # Bind headscale dataDir to persistence
  fileSystems."/var/lib/headscale" = {
    device = "/persist/headscale";
    options = [ "bind" ];
  };

  age.secrets = {
    headscaleClientSecret = {
      file = ../../secrets/headscaleClientSecret.age;
      owner = "headscale";
    };
  };

  doofnet.server = true;

  services.headscale = {
    enable = true;
    settings = lib.mkForce {
      acme_email = "acme@doofnet.uk";
      acme_url = "https://acme-v02.api.letsencrypt.org/directory";
      database = {
        debug = false;
        gorm = {
          parameterized_queries = true;
          prepare_stmt = true;
          skip_err_record_not_found = true;
          slow_threshold = 1000;
        };
        sqlite = {
          path = "/var/lib/headscale/db.sqlite";
          wal_autocheckpoint = 1000;
          write_ahead_log = true;
        };
        type = "sqlite";
      };
      derp = {
        auto_update_enabled = true;
        paths = [ ];
        server = {
          automatically_add_embedded_derp_region = true;
          enabled = true;
          private_key_path = "/var/lib/headscale/derp_server_private.key";
          region_code = "sth";
          region_id = 999;
          region_name = "St. Helens";
          stun_listen_addr = "0.0.0.0:3478";
        };
        update_frequency = "24h";
        urls = [
          "https://controlplane.tailscale.com/derpmap/default"
        ];
      };
      disable_check_updates = false;
      dns = {
        base_domain = "ts.doofnet.uk";
        extra_records = [ ];
        magic_dns = true;
        nameservers = {
          global = [
            "1.1.1.1"
            "1.0.0.1"
            "2606:4700:4700::1111"
            "2606:4700:4700::1001"
          ];
          split = {
            "doofnet.uk" = [
              "10.101.1.2"
              "2001:8b0:bd9:101::2"
              "10.101.1.3"
              "2001:8b0:bd9:101::3"
            ];
            "incognitus.net" = [
              "10.101.1.2"
              "2001:8b0:bd9:101::2"
              "10.101.1.3"
              "2001:8b0:bd9:101::3"
            ];
          };
        };
        search_domains = [
          "ts.doofnet.uk"
          "int.doofnet.uk"
          "doofnet.uk"
        ];
      };
      ephemeral_node_inactivity_timeout = "30m";
      grpc_allow_insecure = false;
      grpc_listen_addr = "127.0.0.1:50443";
      listen_addr = "0.0.0.0:443";
      log = {
        format = "text";
        level = "info";
      };
      logtail = {
        enabled = false;
      };
      metrics_listen_addr = "127.0.0.1:9090";
      noise = {
        private_key_path = "/var/lib/headscale/noise_private.key";
      };
      oidc = {
        client_id = "277dba1f-ac73-4aa3-83e8-2d53f9bbe30b";
        client_secret_path = config.age.secrets.headscaleClientSecret.path;
        issuer = "https://id.doofnet.uk";
        only_start_if_oidc_is_available = true;
        pkce = {
          enabled = true;
        };
      };
      policy = {
        mode = "file";
        path = "/etc/headscale/acl_policy.json";
      };
      prefixes = {
        allocation = "sequential";
        v4 = "100.64.0.0/10";
        v6 = "fd7a:115c:a1e0::/48";
      };
      randomize_client_port = false;
      server_url = "https://hs.doofnet.uk:443";
      tls_letsencrypt_cache_dir = "/var/lib/headscale/cache";
      tls_letsencrypt_challenge_type = "HTTP-01";
      tls_letsencrypt_hostname = "hs.doofnet.uk";
      tls_letsencrypt_listen = ":http";
      unix_socket = "/var/run/headscale/headscale.sock";
      unix_socket_permission = "0770";
    };
  };

  systemd.services.headscale = {
    serviceConfig = {
      AmbientCapabilities = [
        "CAP_NET_BIND_SERVICE"
      ];
      CapabilityBoundingSet = [
        "CAP_NET_BIND_SERVICE"
      ];
    };
  };

  networking.firewall = {
    allowedTCPPorts = [
      80
      443
      3478
    ];
    allowedUDPPorts = [ 3478 ];
  };

  # Write out ACL config
  environment.etc."headscale/acl_policy.json".text = builtins.toJSON acl_config;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
