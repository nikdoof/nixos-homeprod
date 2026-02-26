{ config, ... }:
{
  services.prometheus.alertmanager = {
    enable = true;

    listenAddress = "127.0.0.1";
    webExternalUrl = "https://alertmanager.svc.doofnet.uk";

    configuration = {
      templates = [
        "/etc/alertmanager/config/*.tmpl"
      ];

      receivers = [
        { name = "null"; }
        {
          name = "telegram";
          telegram_configs = [
            {
              bot_token_file = config.age.secrets.alertManagerTelegramToken.path;
              chat_id = -655795395;
              disable_notifications = true;
              send_resolved = true;
              parse_mode = "HTML";
              message = "{{ template \"telegram.doofnet.message\" . }}";
            }
          ];
        }
      ];

      route = {
        group_by = [ "job" ];
        group_wait = "30s";
        group_interval = "5m";
        repeat_interval = "12h";
        receiver = "telegram";
        routes = [
          {
            receiver = "null";
            match = {
              severity = "none";
            };
          }
        ];
      };
    };
  };

  environment.etc = {
    "alertmanager/config/telegram.tmpl".source = ./files/telegram.tmpl;
  };

  age.secrets = {
    alertManagerTelegramToken = {
      file = ../../../secrets/alertManagerTelegramToken.age;
    };
  };

  services.traefik = {
    dynamicConfigOptions = {
      http = {
        routers.alertmanager = {
          rule = "Host(`alertmanager.svc.doofnet.uk`)";
          service = "alertmanager";
        };

        services.alertmanager.loadBalancer.servers = [
          { url = "http://localhost:${toString config.services.prometheus.alertmanager.port}"; }
        ];
      };
    };
  };
}
