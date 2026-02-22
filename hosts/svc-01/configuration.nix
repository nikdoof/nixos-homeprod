{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../hardware/prodesk-600-g3-dm.nix
    ../../hardware/coral-tpu-pcie.nix
    ../../modules/common.nix
    ../../modules/server.nix
    ../../modules/podman.nix
    ../../modules/traefik.nix
    ../../modules/postgresql.nix
    ../../modules/nfs/media.nix
    ../../modules/nfs/paperless.nix
    ./containers.nix
    ./timers.nix
  ];

  # Networking
  networking.useDHCP = false;
  networking.hostName = "svc-01"; # Define your hostname.
  networking.nameservers = [
    "10.101.1.2"
    "2001:8b0:bd9:101::2"
    "10.101.1.3"
    "2001:8b0:bd9:101::3"
  ];
  networking.domain = "int.doofnet.uk";
  networking.search = [ "int.doofnet.uk" ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "eno1";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
  };

  # Printing
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
    extraServiceFiles = {
      zebra = ./cups/AirPrint-Zebra_GK420d.service;
    };
  };

  services.printing = {
    enable = true;
    openFirewall = true;
    defaultShared = true;
    browsing = false;
    listenAddresses = [ "10.101.3.20:631" ];
    allowFrom = [ "all" ];

    drivers = [
      (pkgs.writeTextDir "share/cups/model/Zebra_GK420d.ppd" (builtins.readFile ./cups/Zebra_GK420d.ppd))
    ];
  };

  hardware.printers = {
    ensurePrinters = [
      {
        name = "Zebra_GK420d";
        description = "Zebra GK420d";
        location = "Games Room";
        deviceUri = "usb://Zebra%20Technologies/ZTC%20GK420d?serial=28J120703625";
        model = "Zebra_GK420d.ppd";

        ppdOptions = {
          PageSize = "6.00x4.00";
        };
      }
    ];
    ensureDefaultPrinter = "Zebra_GK420d";
  };

  services.postgresql = {
    ensureDatabases = [
      "gotosocial"
      "miniflux"
      "linkding"
      "paperless"
    ];
    ensureUsers = lib.mkAfter [
      {
        name = "gotosocial";
        ensureDBOwnership = true;
        ensureClauses = {
          createrole = true;
          createdb = true;
          login = true;
          #password = "SCRAM-SHA-256$4096:ccdHuoEyjh5gKX550FCOdQ==$jAm1/d9IRySXwdsb2uby5F71ZY9gFkOK/Sc77W9klBI=:6tN57xZCQIwPtZk9DwmRkjpPa8jVTBTFQj+T7V3HlLc=";
        };
      }
      {
        name = "miniflux";
        ensureDBOwnership = true;
        ensureClauses = {
          createrole = true;
          createdb = true;
          login = true;
          #password = "SCRAM-SHA-256$4096:ccdHuoEyjh5gKX550FCOdQ==$jAm1/d9IRySXwdsb2uby5F71ZY9gFkOK/Sc77W9klBI=:6tN57xZCQIwPtZk9DwmRkjpPa8jVTBTFQj+T7V3HlLc=";
        };
      }
      {
        name = "linkding";
        ensureDBOwnership = true;
        ensureClauses = {
          createrole = true;
          createdb = true;
          login = true;
          #password = "SCRAM-SHA-256$4096:ccdHuoEyjh5gKX550FCOdQ==$jAm1/d9IRySXwdsb2uby5F71ZY9gFkOK/Sc77W9klBI=:6tN57xZCQIwPtZk9DwmRkjpPa8jVTBTFQj+T7V3HlLc=";
        };
      }
      {
        name = "paperless";
        ensureDBOwnership = true;
        ensureClauses = {
          createrole = true;
          createdb = true;
          login = true;
          #password = "SCRAM-SHA-256$4096:ccdHuoEyjh5gKX550FCOdQ==$jAm1/d9IRySXwdsb2uby5F71ZY9gFkOK/Sc77W9klBI=:6tN57xZCQIwPtZk9DwmRkjpPa8jVTBTFQj+T7V3HlLc=";
        };
      }
    ];

    authentication = pkgs.lib.mkOverride 10 ''
      local all all trust
      host sameuser all 127.0.0.1/32 scram-sha-256
      host sameuser all ::1/128 scram-sha-256
      host all all 10.0.0.0/8 scram-sha-256
      host all all 2001:8b0:bd9:101::/64 scram-sha-256
    '';
  };

  services.gitea = {
    enable = true;
    stateDir = "/srv/data/gitea/data";

    database = {
      type = "postgres";
      createDatabase = true;
    };

    settings = {
      mailer = {
        ENABLED = true;
        PROTOCOL = "smtp+starttls";
        SMTP_ADDR = "mx-01.doofnet.uk";
        FROM = "Doofnet Gitea <gitea@doofnet.uk>";
        USER = "gitea@doofnet.uk";
      };
      server = {
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 9990;
        DOMAIN = "git.doofnet.uk";
        ROOT_URL = "https://git.doofnet.uk";
        DISABLE_SSH = true;
      };
      service = {
        DISABLE_REGISTRATION = true;
      };
    };
  };

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
                }
                {
                  type = "monitor";
                  cache = "1m";
                  title = "Services";
                  sites = [
                    {
                      title = "Jellyfin";
                      url = "https://jellyfin.svc.doofnet.uk";
                      icon = "si:jellyfin";
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
    staticConfigOptions = {
      entryPoints = {
        extweb = {
          address = ":8080";
          asDefault = false;
          http.redirections.entrypoint = {
            to = "extwebsecure";
            scheme = "https";
          };
        };

        extwebsecure = {
          address = ":8443";
          asDefault = false;
          http.tls.certResolver = "letsencrypt";
        };
      };
    };
    dynamicConfigOptions = {
      http = {
        routers.gitea = {
          rule = "Host(`git.doofnet.uk`)";
          service = "gitea";
        };

        services.gitea.loadBalancer.servers = [
          { url = "http://127.0.0.1:9990"; }
        ];

        routers.glance = {
          rule = "Host(`home.svc.doofnet.uk`)";
          service = "glances";
        };

        services.glance.loadBalancer.servers = [
          { url = "http://127.0.0.1:${toString config.services.glance.settings.server.port}"; }
        ];

        middlewares = {
          auth-headers = {
            headers = {
              sslRedirect = true;
              stsSeconds = 315360000;
              browserXssFilter = true;
              contentTypeNosniff = true;
              forceSTSHeader = true;
              sslHost = "doofnet.uk";
              stsIncludeSubdomains = true;
              stsPreload = true;
              frameDeny = true;
            };
          };

          # Redirects if not authenticated
          oauth-auth-redirect = {
            forwardAuth = {
              address = "http://127.0.0.1:4180/oauth2/";
              trustForwardHeader = true;
              authResponseHeaders = [
                "X-Auth-Request-Access-Token"
                "Authorization"
              ];
            };
          };

          # Throws 401 without redirecting
          oauth-auth-wo-redirect = {
            forwardAuth = {
              address = "http://127.0.0.1:4180/oauth2/auth";
              trustForwardHeader = true;
              authResponseHeaders = [
                "X-Auth-Request-Access-Token"
                "Authorization"
              ];
            };
          };
        };
      };
    };
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
