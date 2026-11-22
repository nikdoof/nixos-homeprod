{
  config,
  lib,
  pkgs,
  ...
}:
let
  dataDir = "/srv/data/boohootodo";
  image = "ghcr.io/nikdoof/boohootodo:main";
  migrateDatabase = pkgs.writeShellScript "boohootodo-db-upgrade" ''
    exec ${pkgs.podman}/bin/podman run --rm --pull=missing \
      --env-file=${config.age.secrets.boohootodoEnvironment.path} \
      --env DATABASE_URL=sqlite:////data/boohootodo.db \
      --volume ${dataDir}:/data:U \
      ${image} \
      uv run --no-sync flask --app boohootodo db upgrade
  '';
in
{
  age.secrets.boohootodoEnvironment.file = ../../../secrets/boohootodoEnvironment.age;

  virtualisation.oci-containers.containers.boohootodo = {
    inherit image;
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.boohootodo.rule" = "Host(`todo.doofnet.uk`)";
      "traefik.http.routers.boohootodo.entrypoints" = "websecure,extwebsecure";
      "traefik.http.services.boohootodo.loadbalancer.server.port" = "8000";
    };
    environment = {
      APP_TIMEZONE = "Europe/London";
      DATABASE_URL = "sqlite:////data/boohootodo.db";
      OIDC_ISSUER = "https://id.doofnet.uk";
      OIDC_DISCOVERY_URL = "https://id.doofnet.uk/.well-known/openid-configuration";
      OIDC_CLIENT_ID = "116a0f2e-9b56-4f61-abcb-9bc3e22a646c";
      OIDC_CLIENT_AUTH_METHOD = "none";
      OIDC_REDIRECT_URI = "https://todo.doofnet.uk/auth/oidc/callback";
      SESSION_COOKIE_SECURE = "true";
    };
    environmentFiles = [ config.age.secrets.boohootodoEnvironment.path ];
    volumes = [ "${dataDir}:/data:U" ];
  };

  # Run the app's documented Flask-Migrate upgrade before each container start.
  systemd.services."podman-boohootodo" = {
    after = [ "systemd-tmpfiles-setup.service" ];
    requires = [ "systemd-tmpfiles-setup.service" ];
    serviceConfig.ExecStartPre = lib.mkBefore [ (toString migrateDatabase) ];
  };

  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 root root -" ];
  services.borgmatic.settings.source_directories = [ dataDir ];
}
