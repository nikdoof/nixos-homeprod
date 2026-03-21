{ config, pkgs, ... }:
let
  secretPath = config.age.secrets.grafanaOidcClientSecret.path;
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

      # Creates a *mutable* dashboard provider, pulling from /etc/grafana-dashboards.
      # With this, you can manually provision dashboards from JSON with `environment.etc` like below.
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
        {
          orgId = 1;
          name = "GlobalTalk";
          folder = "Alerts";
          interval = "5m";
          rules = [
            {
              uid = "atalkd-net-mismatch";
              title = "GlobalTalk network collision";
              condition = "C";
              for = "0s";
              noDataState = "OK";
              execErrState = "Error";
              annotations.summary = "AppleTalk daemon on afp-01 is reporting a network collision.";
              data = [
                {
                  refId = "A";
                  datasourceUid = "loki";
                  queryType = "instant";
                  relativeTimeRange = {
                    from = 300;
                    to = 0;
                  };
                  model = {
                    refId = "A";
                    queryType = "instant";
                    datasource = {
                      type = "loki";
                      uid = "loki";
                    };
                    expr = ''count(rate({host="afp-01", unit="atalkd.service"} |~ `rtmp_packet (last|first)net mismatch (\d*)!=(\d*)` [5m]))'';
                  };
                }
                {
                  refId = "B";
                  datasourceUid = "__expr__";
                  model = {
                    refId = "B";
                    type = "reduce";
                    expression = "A";
                    reducer = "last";
                    datasource = {
                      type = "__expr__";
                      uid = "__expr__";
                    };
                  };
                }
                {
                  refId = "C";
                  datasourceUid = "__expr__";
                  model = {
                    refId = "C";
                    type = "threshold";
                    expression = "B";
                    datasource = {
                      type = "__expr__";
                      uid = "__expr__";
                    };
                    conditions = [
                      {
                        evaluator = {
                          params = [ 1 ];
                          type = "gt";
                        };
                        operator = {
                          type = "and";
                        };
                        query = {
                          params = [ "B" ];
                        };
                        reducer = {
                          type = "last";
                        };
                        type = "query";
                      }
                    ];
                  };
                }
              ];
            }
          ];
        }
      ];

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
}
