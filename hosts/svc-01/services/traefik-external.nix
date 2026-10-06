_: {
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

    dynamicConfigOptions.http = {
      routers.hermes-dashboard = {
        rule = "Host(`hermes.doofnet.uk`)";
        entryPoints = [
          "websecure"
          "extwebsecure"
        ];
        service = "hermes-dashboard";
      };

      services.hermes-dashboard.loadBalancer = {
        passHostHeader = true;
        servers = [
          { url = "https://hermes.svc.doofnet.uk"; }
        ];
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    8080
    8443
  ];
}
