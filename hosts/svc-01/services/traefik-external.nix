{ ... }:
{
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
  };

  networking.firewall.allowedTCPPorts = [
    8080
    8443
  ];
}
