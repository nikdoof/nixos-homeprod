{ config, ... }:
{
  age.secrets = {
    oauth2ClientSecret = {
      file = ../../../secrets/oauth2ClientSecret.age;
    };
  };

  virtualisation.oci-containers.containers.oauth2-proxy = {
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.oauth2-proxy.rule" =
        "Host(`oauth2-proxy.svc.doofnet.uk`) || PathPrefix(`/oauth2/`)";
      "traefik.http.routers.oauth2-proxy.middlewares" = "auth-headers@file";
      "traefik.http.services.oauth2-proxy.loadbalancer.server.port" = "4180";
    };
    image = "quay.io/oauth2-proxy/oauth2-proxy:v7.14.2";
    environmentFiles = [ config.age.secrets.oauth2ClientSecret.path ];
    cmd = [
      "--provider=oidc"
      "--oidc-issuer-url=https://id.doofnet.uk"
      "--provider-display-name=Doofnet Auth"
      "--code-challenge-method=S256"
      "--email-domain=*"
      "--upstream=static://202"
      "--http-address=0.0.0.0:4180"
      "--pass-user-headers=true"
      "--pass-authorization-header=true"
      "--set-authorization-header=true"
      "--pass-access-token=true"
      "--set-xauthrequest=true"
      "--reverse-proxy=true"
      "--skip-provider-button"
      "--allowed-group=home"
      "--real-client-ip-header=X-Forwarded-For"
      "--cookie-csrf-per-request=true"
      "--cookie-csrf-expire=5m"
      "--cookie-domain=doofnet.uk"
    ];
    ports = [ "127.0.0.1:4180:4180" ];
  };

  services.traefik = {
    dynamicConfigOptions = {
      http = {
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
}
