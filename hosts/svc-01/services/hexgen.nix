_: {
  virtualisation.oci-containers.containers = {
    hexgen = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.hexgen.rule" = "Host(`hexgen.doofnet.uk`)";
        "traefik.http.services.hexgen.loadbalancer.server.port" = "5000";
        "traefik.http.routers.hexgen.entrypoints" = "websecure,extwebsecure";
      };
      image = "ghcr.io/nikdoof/hexgen:1.2.0";
    };
  };
}
