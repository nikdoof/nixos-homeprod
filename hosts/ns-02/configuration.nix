{
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../hardware/esxi-vm.nix
    ../../modules/common.nix
    ../../modules/server.nix
    ../../modules/bind
  ];

  # Networking
  networking.useDHCP = false;
  networking.hostName = "ns-02";
  networking.nameservers = [
    "127.0.0.1"
  ];
  networking.domain = "int.doofnet.uk";
  networking.search = [ "int.doofnet.uk" ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "eth0";
    address = [
      "10.101.1.2/24"
      "2001:8b0:bd9:101::2/64"
      "fddd:d00f:dab0:101::2/64"
    ];
    routes = [
      { Gateway = "10.101.1.1"; }
    ];
    networkConfig = {
      IPv6AcceptRA = true;
    };
  };

  services.traefik = {
    staticConfigOptions = {
      api = true;

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

      dynamicConfigOptions = {

        http.routers = {
          api = {
            rule = "Host(`traefik.svc.doofnet.uk`)";
            service = "api@internal";
          };
        };

        http.middlewares = {
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
