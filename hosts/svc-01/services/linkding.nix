{ config, lib, ... }:
{

  age.secrets.linkdingEnvironment = {
    file = ../../../secrets/linkdingEnvironment.age;
  };

  services.postgresql = {
    ensureDatabases = [
      "linkding"
    ];
    ensureUsers = lib.mkAfter [
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
    ];
  };

  virtualisation.oci-containers.containers.linkding = {
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.linkding.rule" = "Host(`link.doofnet.uk`)";
      "traefik.http.services.linkding.loadbalancer.server.port" = "9090";
      "traefik.http.routers.linkding.entrypoints" = "websecure,extwebsecure";
    };
    image = "sissbruecker/linkding:1.45.0";
    environment = {
      LD_DB_ENGINE = "postgres";
      LD_DB_HOST = "10.88.0.1";
      LD_DB_PORT = "5432";
      LD_DB_USER = "linkding";
      LD_DB_DATABASE = "linkding";
      LD_ENABLE_OIDC = "True";
      OIDC_OP_AUTHORIZATION_ENDPOINT = "https://id.doofnet.uk/authorize";
      OIDC_OP_TOKEN_ENDPOINT = "https://id.doofnet.uk/api/oidc/token";
      OIDC_OP_USER_ENDPOINT = "https://id.doofnet.uk/api/oidc/userinfo";
      OIDC_OP_JWKS_ENDPOINT = "https://id.doofnet.uk/.well-known/jwks.json";
      OIDC_USERNAME_CLAIM = "username";
    };
    environmentFiles = [ config.age.secrets.linkdingEnvironment.path ];
  };
}
