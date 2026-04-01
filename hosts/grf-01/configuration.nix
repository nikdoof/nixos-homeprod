{
  pkgs,
  ...
}:
let
  hostName = "grf-01";
  domainName = "int.doofnet.uk";

  dashboards = pkgs.stdenv.mkDerivation {
    name = "grafana-dashboards";
    src = ./files/dashboards;
    phases = [
      "unpackPhase"
      "installPhase"
    ];
    installPhase = ''
      mkdir -p $out
      cp -r $src/* $out
    '';
  };
in
{
  doofnet.microvm = {
    enable = true;
    cid = 15;
    vlan = "101";
  };

  # Networking
  networking.useDHCP = false;
  networking.hostName = hostName;
  networking.nameservers = [
    "10.101.1.2"
    "10.101.1.3"
    "2001:8b0:bd9:101::2"
    "2001:8b0:bd9:101::3"
  ];
  networking.domain = domainName;
  networking.search = [ domainName ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [
        "10.101.3.31/16"
        "2001:8b0:bd9:101::3:31/64"
        "fddd:d00f:dab0:101::3:31/64"
      ];
      Gateway = "10.101.1.1";
      IPv6AcceptRA = true;
      DHCP = "no";
      MulticastDNS = true;
    };
  };

  doofnet.server = true;

  services.grafana = {
    enable = true;
    openFirewall = true;

    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
        enforce_domain = false;
        enable_gzip = true;
        domain = "globaltalk.doofnet.uk";
      };
      auth = {
        disable_login_form = true;
      };
      "auth.anonymous" = {
        enabled = true;
        org_name = "Main Org.";
        org_role = "Viewer";
      };

      alerting = {
        enabled = false;
      };
      unified_alerting = {
        enabled = false;
      };
      smtp = {
        enabled = true;
        from_address = "grafana@doofnet.uk";
        host = "mx-01.doofnet.uk";
        startTLS_policy = "OpportunisticStartTLS";
      };
      analytics = {
        reporting_enabled = false;
        feedback_links_enabled = false;
      };
      dashboards = {
        default_home_dashboard_path = "${dashboards}/globaltalk.json";
      };
    };

    provision = {
      enable = true;

      dashboards.settings.providers = [
        {
          name = "Dashboards";
          disableDeletion = true;
          options = {
            path = dashboards;
            foldersFromFilesStructure = true;
          };
        }
      ];

      datasources.settings.datasources = [
        {
          name = "prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://svc-02.int.doofnet.uk:9090";
          isDefault = true;
          editable = false;
        }
      ];
    };
  };

  # Bind grafana dataDir to persistence
  fileSystems."/var/lib/grafana" = {
    device = "/persist/grafana";
    options = [ "bind" ];
  };

  # Install the treemap panel
  systemd.services.grafana.serviceConfig.ExecStartPre =
    "${pkgs.grafana}/bin/grafana-cli plugins install marcusolsson-treemap-panel";

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
