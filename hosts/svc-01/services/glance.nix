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
                    {
                      title = "Gitea";
                      url = "https://git.doofnet.uk";
                      icon = "si:gitea";
                    }
                    {
                      title = "GoToSocial";
                      url = "https://social.doofnet.uk";
                      icon = "si:activitypub";
                    }
                    {
                      title = "Mastodon";
                      url = "https://mastodon.incognitus.net";
                      icon = "si:mastodon";
                    }
                    {
                      title = "Rustical";
                      url = "https://cal.doofnet.uk";
                      icon = "mdi:calendar-sync";
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
                {
                  type = "custom-api";
                  title = "F1 - Next Race";
                  cache = "2h";
                  url = "https://f1api.dev/api/current/next";
                  template = ''
                    <div class="flex flex-column gap-10">
                      {{ $session := index (.JSON.Array "race") 0 }}
                      <p class="size-h5">
                        Round {{ .JSON.String "round" }}
                      </p>

                      <div class="margin-block-4">
                        <p class="color-highlight">{{ $session.String "raceName" }}</p>
                        <p class="color-primary">
                          <span>Race</span>
                          {{ $datetime := concat ($session.String "schedule.race.date") "T" ($session.String "schedule.race.time") }}
                          <span
                            class="color-highlight"
                            title="{{ $session.String "schedule.race.date" }}"
                            {{ parseRelativeTime "rfc3339" $datetime }}
                          ></span>
                        </p>
                        <p class="size-h5">{{ $session.String "schedule.race.date" }} at {{ $session.String "schedule.race.time" }}</p>
                      </div>

                      <ul class="size-h5 attachments">
                        <li>{{ $session.String "circuit.country" }}</li>
                        <li>{{ $session.String "circuit.city" }}</li>
                        <li>{{ $session.String "circuit.circuitName" }}</li>
                      </ul>
                    </div>
                  '';
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
