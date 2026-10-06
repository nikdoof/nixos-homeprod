{
  config,
  lib,
  pkgs,
  ...
}:
{

  doofnet.microvm = {
    enable = true;
    cid = 16;
    vlan = "101";
    mem = 2050;
  };

  environment.systemPackages = with pkgs; [
    curl
    fd
    gh
    git
    jq
    nodejs
    python3
    ripgrep
    shellcheck
    tree
    wget
    yq
  ];

  # Networking
  networking.hostName = "hrm-01";
  networking.nameservers = [
    "10.101.1.2"
    "10.101.1.3"
    "2001:8b0:bd9:101::2"
    "2001:8b0:bd9:101::3"
  ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [
        "10.101.3.32/16"
        "2001:8b0:bd9:101::3:32/64"
        "fddd:d00f:dab0:101::3:32/64"
      ];
      Gateway = "10.101.1.1";
      IPv6AcceptRA = true;
      DHCP = "no";
    };
    dhcpV6Config.UseDelegatedPrefix = false;
  };

  virtualisation.docker.enable = false;
  virtualisation.podman.enable = true;
  virtualisation.containers.storage.settings.storage.graphroot = "/persist/containers/storage";

  systemd.tmpfiles.rules = [
    "d /persist/containers/storage 0700 root root -"
  ];

  age.secrets = {
    hermesEnv = {
      file = ../../secrets/hermesEnv.age;
    };
    digitalOceanApiToken = {
      file = ../../secrets/digitalOceanApiToken.age;
      owner = "acme";
    };
  };

  security.acme.certs."hermes.svc.doofnet.uk" = {
    dnsProvider = "digitalocean";
    dnsResolver = "1.1.1.1:53";
    group = "nginx";
    environmentFile = pkgs.writeText "acme-env" ''
      DO_AUTH_TOKEN_FILE=${config.age.secrets.digitalOceanApiToken.path}
    '';
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    virtualHosts."hermes.svc.doofnet.uk" = {
      onlySSL = true;
      useACMEHost = "hermes.svc.doofnet.uk";
      serverAliases = [ "hermes.doofnet.uk" ];
      listen = [
        {
          addr = "10.101.3.32";
          port = 443;
          ssl = true;
        }
      ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:9119";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header Origin $http_origin;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
          proxy_buffering off;
        '';
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 443 ];

  systemd.services.hermes-dashboard = {
    description = "Hermes Agent Web Dashboard";
    wantedBy = [ "multi-user.target" ];
    after = [ "hermes-agent.service" ];
    requires = [ "hermes-agent.service" ];
    partOf = [ "hermes-agent.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = pkgs.writeShellScript "hermes-dashboard" ''
        exec ${builtins.head (builtins.match "([^ ]+) gateway" config.systemd.services.hermes-agent.serviceConfig.ExecStart)} dashboard --host 0.0.0.0 --port 9119 --no-open
      '';
      User = config.services.hermes-agent.user;
      Group = config.services.hermes-agent.group;
      WorkingDirectory = config.services.hermes-agent.workingDirectory;
      EnvironmentFile = config.services.hermes-agent.environmentFiles;
      Restart = "on-failure";
      RestartSec = 5;
    };
    environment = config.systemd.services.hermes-agent.environment // {
      PATH = lib.mkForce config.systemd.services.hermes-agent.environment.PATH;
    };
  };

  services.hermes-agent = {
    enable = true;
    stateDir = "/persist/hermes";
    settings = {
      dashboard = {
        theme = "midnight";
        font = "work-sans";
        public_url = "https://hermes.doofnet.uk";
        oauth = {
          provider = "self-hosted";
          self_hosted = {
            issuer = "https://id.doofnet.uk";
            client_id = "77d16268-c85f-4449-90ea-39ac5c860c7c";
            scopes = "openid profile email";
          };
        };
      };
      model.default = "openai/gpt-6-luna";
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
      };
      terminal = {
        backend = "local";
        cwd = ".";
        timeout = 180;
      };
      compression = {
        enabled = true;
        threshold = 0.85;
        summary_model = "google/gemini-3-flash-preview";
      };
    };
    environmentFiles = [
      config.age.secrets.hermesEnv.path
    ];

    addToSystemPackages = true;

    extraDependencyGroups = [
      "messaging"
      "web"
    ];

  };

  users.users.hermes.linger = true;
  systemd.services.hermes-agent = {
    after = [ "linger-users.service" ];
    wants = [ "linger-users.service" ];
    preStart = ''
      for _ in $(seq 1 50); do
        [ -S "/run/user/$(id -u)/bus" ] && break
        sleep 0.2
      done
      if [ ! -S "/run/user/$(id -u)/bus" ]; then
        echo "hermes-agent: no user bus after 10s; cron dispatch may fail" >&2
      fi
    '';
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
