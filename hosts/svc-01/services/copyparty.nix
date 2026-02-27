{ ... }:
{
  virtualisation.oci-containers.containers.copyparty = {
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.copyparty.rule" = "Host(`files.doofnet.uk`)";
      "traefik.http.services.copyparty.loadbalancer.server.port" = "3923";
      "traefik.http.routers.copyparty.entrypoints" = "websecure,extwebsecure";
    };
    image = "ghcr.io/9001/copyparty-ac:1.20.10";
    volumes = [
      "/srv/data/copyparty/data:/w"
      "/srv/data/copyparty/config/doofnet.conf:/cfg/doofnet.conf:U"
    ];
  };
}
