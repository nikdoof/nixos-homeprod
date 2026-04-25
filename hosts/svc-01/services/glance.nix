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
                  title = "Media";
                  sites = [
                    {
                      title = "Jellyfin";
                      url = "https://jellyfin.svc.doofnet.uk";
                      icon = "si:jellyfin";
                      check-url = "https://jellyfin.svc.doofnet.uk/health";
                    }
                    {
                      title = "Radarr";
                      url = "https://radarr.svc.doofnet.uk";
                      icon = "si:radarr";
                      expected-status-codes = [
                        200
                        302
                      ];
                    }
                    {
                      title = "Sonarr";
                      url = "https://sonarr.svc.doofnet.uk";
                      icon = "si:sonarr";
                      expected-status-codes = [
                        200
                        302
                      ];
                    }
                    {
                      title = "Prowlarr";
                      url = "https://prowlarr.svc.doofnet.uk";
                      icon = "auto-invert sh:prowlarr-dark";
                      expected-status-codes = [
                        200
                        302
                      ];
                    }
                    {
                      title = "Lidarr";
                      url = "https://lidarr.svc.doofnet.uk";
                      icon = "si:lidarr";
                      expected-status-codes = [
                        200
                        302
                      ];
                    }
                    {
                      title = "iPlayarr";
                      url = "https://iplayarr.svc.doofnet.uk";
                      icon = "mdi:play-box";
                      expected-status-codes = [
                        200
                        302
                      ];
                    }
                    {
                      title = "Calibre Web";
                      url = "https://calibre-web.svc.doofnet.uk";
                      icon = "auto-invert sh:calibre-web-dark";
                      expected-status-codes = [
                        200
                        302
                      ];
                    }
                    {
                      title = "OpenBooks";
                      url = "https://openbooks.svc.doofnet.uk";
                      icon = "auto-invert sh:openbooks-dark";
                      expected-status-codes = [
                        200
                        302
                      ];
                    }
                    {
                      title = "Qbittorrent";
                      url = "https://qbittorrent.svc.doofnet.uk";
                      icon = "si:qbittorrent";
                      expected-status-codes = [
                        200
                        302
                      ];
                    }
                    {
                      title = "NzbGet";
                      url = "https://nzbget.svc.doofnet.uk";
                      icon = "mdi:download";
                      expected-status-codes = [
                        200
                        302
                      ];
                    }
                  ];
                }
                {
                  type = "monitor";
                  cache = "1m";
                  title = "Tools";
                  sites = [
                    {
                      title = "Paperless";
                      url = "https://paperless.svc.doofnet.uk";
                      icon = "si:paperlessngx";
                      expected-status-codes = [
                        200
                        302
                      ];
                    }
                    {
                      title = "ScanServJS";
                      url = "https://scan.svc.doofnet.uk";
                      icon = "auto-invert mdi:scanner";
                    }
                    {
                      title = "Linkding";
                      url = "https://link.doofnet.uk";
                      icon = "auto-invert sh:linkding-dark";
                      expected-status-codes = [
                        200
                        302
                      ];
                    }
                    {
                      title = "Miniflux";
                      url = "https://rss.doofnet.uk";
                      icon = "auto-invert sh:miniflux-dark";
                      check-url = "https://rss.doofnet.uk/healthcheck";
                    }
                    {
                      title = "CopyParty";
                      url = "https://files.doofnet.uk";
                      icon = "auto-invert sh:copyparty-dark";
                    }
                    {
                      title = "Rustical";
                      url = "https://cal.doofnet.uk";
                      icon = "mdi:calendar-sync";
                    }
                    {
                      title = "Scrumboy";
                      url = "https://scrum.doofnet.uk";
                      icon = "mdi:developer-board";
                      expected-status-codes = [
                        200
                        302
                      ];
                    }
                  ];
                }
                {
                  type = "monitor";
                  cache = "1m";
                  title = "Infrastructure";
                  sites = [
                    {
                      title = "Pocket ID";
                      url = "https://id.doofnet.uk";
                      icon = "auto-invert sh:pocket-id";
                    }
                    {
                      title = "Grafana";
                      url = "https://grafana.svc.doofnet.uk";
                      icon = "auto-invert sh:grafana-dark";
                      check-url = "https://grafana.svc.doofnet.uk/api/health";
                    }
                    {
                      title = "UniFi";
                      url = "https://unifi.svc.doofnet.uk";
                      icon = "si:ubiquiti";
                      expected-status-codes = [
                        200
                        302
                      ];
                    }
                    {
                      title = "Gitea";
                      url = "https://git.doofnet.uk";
                      icon = "si:gitea";
                    }
                  ];
                }
                {
                  type = "monitor";
                  cache = "1m";
                  title = "Social";
                  sites = [
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
                  ];
                }
                {
                  type = "bookmarks";
                  title = "Hosted Sites";
                  groups = [
                    {
                      links = [
                        {
                          title = "doofnet.uk";
                          url = "https://doofnet.uk";
                        }
                        {
                          title = "nikdoof.com";
                          url = "https://nikdoof.com";
                        }
                        {
                          title = "incognitus.net";
                          url = "https://incognitus.net";
                        }
                        {
                          title = "2315media.com";
                          url = "https://2315media.com";
                        }
                        {
                          title = "bluecalx.co.uk";
                          url = "https://bluecalx.co.uk";
                        }
                      ];
                    }
                    {
                      links = [
                        {
                          title = "dimension.sh";
                          url = "https://dimension.sh";
                        }
                        {
                          title = "hereforthis.uk";
                          url = "https://hereforthis.uk";
                        }
                        {
                          title = "intellectops.com";
                          url = "https://intellectops.com";
                        }
                        {
                          title = "oojamaflip.wtf";
                          url = "https://oojamaflip.wtf";
                        }
                        {
                          title = "parkpioneer.com";
                          url = "https://parkpioneer.com";
                        }
                      ];
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
                {
                  type = "releases";
                  repositories = [
                    "jellyfin/jellyfin"
                    "paperless-ngx/paperless-ngx"
                    "Radarr/Radarr"
                    "Sonarr/Sonarr"
                    "Prowlarr/Prowlarr"
                    "miniflux/v2"
                    "sissbruecker/linkding"
                    "go-gitea/gitea"
                    "superseriousbusiness/gotosocial"
                    "mastodon/mastodon"
                    "oauth2-proxy/oauth2-proxy"
                    "9001/copyparty"
                  ];
                }
                {
                  type = "lobsters";
                  limit = 15;
                  sort-by = "hot";
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
