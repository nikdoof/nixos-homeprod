{
  config,
  pkgs,
  ...
}:
{

  doofnet.microvm = {
    enable = true;
    cid = 16;
    vlan = "101";
  };

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
      useACMEHost = "hermes.svc.doofnet.uk";
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
        exec ${pkgs.podman}/bin/podman exec \
          --user "$(${pkgs.coreutils}/bin/id -u hermes):$(${pkgs.coreutils}/bin/id -g hermes)" \
          hermes-agent \
          /data/current-package/bin/hermes dashboard \
          --host 127.0.0.1 --port 9119 --no-open
      '';
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  services.hermes-agent = {
    enable = true;
    settings.model.default = "openrouter/owl-alpha";

    environmentFiles = [
      config.age.secrets.hermesEnv.path
    ];

    container.enable = true;
    container.backend = "podman";
    container.image = "docker.io/library/ubuntu:24.04";
    container.hostUsers = [ "nikdoof" ];
    addToSystemPackages = true;

    extraDependencyGroups = [
      "messaging"
      "web"
    ];
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
