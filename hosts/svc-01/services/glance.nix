{ config, ... }:
{
  services.glance = {
    enable = true;
    settings = {
      server = {
        port = 9991;
        proxied = true;
      };
      theme = {
        background-color = "229 19 23";
        contrast-multiplier = 1.2;
        primary-color = "222 74 74";
        positive-color = "96 44 68";
        negative-color = "359 68 71";
      };
      pages = [
        {
          name = "Startpage";
          width = "slim";
          hide-desktop-navigation = true;
          center-vertically = true;
          columns = [
            {
              size = "full";
              widgets = [
                {
                  type = "search";
                  autofocus = true;
                  search-engine = "kagi";
                }
                {
                  type = "monitor";
                  cache = "1m";
                  title = "Services";
                  sites = [
                    {
                      title = "Pocket ID";
                      url = "https://id.doofnet.uk";
                      icon = "auto-invert sh:pocket-id";
                    }
                    {
                      title = "OpenBooks";
                      url = "https://openbooks.svc.doofnet.uk";
                      icon = "auto-invert sh:openbooks-dark";
                    }
                    {
                      title = "Jellyfin";
                      url = "https://jellyfin.svc.doofnet.uk";
                      icon = "si:jellyfin";
                    }
                    {
                      title = "Prowlarr";
                      url = "https://prowlarr.svc.doofnet.uk";
                      icon = "auto-invert sh:prowlarr-dark";
                    }
                    {
                      title = "Sonarr";
                      url = "https://sonarr.svc.doofnet.uk";
                      icon = "si:sonarr";
                    }
                    {
                      title = "Radarr";
                      url = "https://radarr.svc.doofnet.uk";
                      icon = "si:radarr";
                    }
                    {
                      title = "Calibre Web";
                      url = "https://calibre-web.svc.doofnet.uk";
                      icon = "auto-invert sh:calibre-web-dark";
                    }
                    {
                      title = "Miniflux";
                      url = "https://rss.doofnet.uk";
                      icon = "auto-invert sh:miniflux-dark";
                    }
                    {
                      title = "Linkding";
                      url = "https://link.doofnet.uk";
                      icon = "auto-invert sh:linkding-dark";
                    }
                    {
                      title = "CopyParty";
                      url = "https://files.doofnet.uk";
                      icon = "auto-invert sh:copyparty-dark";
                    }
                    {
                      title = "Paperless";
                      url = "https://paperless.svc.doofnet.uk";
                      icon = "si:paperlessngx";
                    }
                    {
                      title = "ScanServJS";
                      url = "https://scan.svc.doofnet.uk";
                      icon = "auto-invert mdi:scanner";
                    }
                    {
                      title = "UniFi";
                      url = "https://unifi.svc.doofnet.uk";
                      icon = "si:ubiquiti";
                    }
                    {
                      title = "Grafana";
                      url = "https://grafana.svc.doofnet.uk";
                      icon = "auto-invert sh:grafana-dark";
                    }
                  ];
                }
              ];
            }
            {
              size = "small";
              widgets = [
                {
                  type = "clock";
                  hour-format = "24h";
                  timezones = [
                    {
                      timezone = "Europe/Paris";
                      label = "Paris";
                    }
                    {
                      timezone = "America/New_York";
                      label = "Orlando";
                    }
                  ];
                }
                {
                  type = "weather";
                  units = "metric";
                  hour-format = "24h";
                  location = "Saint Helens, United Kingdom";
                }
                {
                  type = "markets";
                  markets = [
                    {
                      symbol = "GBPUSD=X";
                      name = "GBP->USD";
                    }
                  ];
                }
              ];
            }
          ];
        }
      ];
    };
  };

  services.traefik = {
    dynamicConfigOptions = {
      http = {
        routers.glance = {
          rule = "Host(`home.svc.doofnet.uk`)";
          service = "glance";
        };

        services.glance.loadBalancer.servers = [
          { url = "http://127.0.0.1:${toString config.services.glance.settings.server.port}"; }
        ];
      };
    };
  };
}
