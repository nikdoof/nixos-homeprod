{ config, pkgs, ... }:
let
  secretPath = config.age.secrets.grafanaOidcClientSecret.path;
  telegramTokenPath = config.age.secrets.grafanaTelegramToken.path;

  inherit (import ./grafana/lib.nix) mkPromData;

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
  age.secrets.grafanaOidcClientSecret = {
    file = ../../../secrets/grafanaOidcClientSecret.age;
    owner = "grafana";
  };

  age.secrets.grafanaTelegramToken = {
    file = ../../../secrets/alertManagerTelegramToken.age;
    owner = "grafana";
  };

  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
        enforce_domain = false;
        enable_gzip = true;
        domain = "grafana.svc.doofnet.uk";
        root_url = "https://grafana.svc.doofnet.uk";
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
      auth = {
        disable_login_form = false;
        oauth_auto_login = false;
      };
      "auth.generic_oauth" = {
        enabled = true;
        name = "Pocket ID";
        client_id = "590ca225bf4cd85c2d4c4f65a38067b096675715";
        client_secret = "$__file{${secretPath}}";
        scopes = "openid profile email groups";
        auth_url = "https://id.doofnet.uk/authorize";
        token_url = "https://id.doofnet.uk/api/oidc/token";
        api_url = "https://id.doofnet.uk/api/oidc/userinfo";
        use_pkce = true;
        use_refresh_token = true;
        email_attribute_path = "email";
        login_attribute_path = "preferred_username";
        name_attribute_path = "name";
        role_attribute_path = "contains(groups[*], 'admin') && 'Admin' || 'Viewer'";
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

      alerting.rules.settings.groups = [
        (import ./grafana/alert-hardware.nix mkPromData)
        (import ./grafana/alert-infrastructure.nix mkPromData)
        (import ./grafana/alert-services.nix mkPromData)
        (import ./grafana/alert-globaltalk.nix)
        (import ./grafana/alert-homeassistant.nix mkPromData)
        (import ./grafana/alert-suricata.nix)
      ];

      alerting.contactPoints.settings = {
        contactPoints = [
          {
            name = "Telegram";
            receivers = [
              {
                uid = "telegram-main";
                type = "telegram";
                settings = {
                  botToken = "$__file{${telegramTokenPath}}";
                  chatID = "-655795395";
                  parseMode = "HTML";
                };
              }
            ];
          }
        ];
        deleteContactPoints = [
          {
            orgId = 1;
            uid = "grafana-default-email";
          }
        ];
      };

      alerting.policies.settings = {
        policies = [
          {
            orgId = 1;
            receiver = "Telegram";
          }
        ];
      };

      datasources.settings.datasources = [
        {
          name = "prometheus";
          type = "prometheus";
          uid = "prometheus";
          access = "proxy";
          url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
          isDefault = true;
          editable = false;
        }
        {
          name = "loki";
          type = "loki";
          uid = "loki";
          url = "https://loki.svc.doofnet.uk";
        }
      ];
    };
  };

  services.traefik = {
    dynamicConfigOptions = {
      http = {
        routers.grafana = {
          rule = "Host(`grafana.svc.doofnet.uk`)";
          service = "grafana";
        };

        services.grafana.loadBalancer.servers = [
          { url = "http://localhost:${toString config.services.grafana.settings.server.http_port}"; }
        ];
      };
    };
  };

  # Alloy config
  environment.etc."alloy/conf.d/02-grafana.alloy".text = ''
    prometheus.scrape "grafana" {
      targets    = [{"__address__" = "127.0.0.1:${toString config.services.grafana.settings.server.http_port}"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "grafana"
    }
  '';
}
