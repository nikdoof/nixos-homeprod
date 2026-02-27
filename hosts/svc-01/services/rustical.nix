{ config, ... }:

{
  age.secrets = {
    rusticalClientSecret = {
      file = ../../../secrets/rusticalClientSecret.age;
    };
  };

  # Rustical
  virtualisation.oci-containers.containers.rustical = {
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.rustical.rule" = "Host(`cal.doofnet.uk`)";
      "traefik.http.services.rustical.loadbalancer.server.port" = "4000";
      "traefik.http.routers.rustical.entrypoints" = "websecure,extwebsecure";
    };
    image = "ghcr.io/lennart-k/rustical:0.12.9";
    environmentFiles = [ config.age.secrets.rusticalClientSecret.path ];
    volumes = [
      "/srv/data/rustical/config/config.toml:/etc/rustical/config.toml:U"
      "/srv/data/rustical/data:/var/lib/rustical:U"
    ];
  };
}
