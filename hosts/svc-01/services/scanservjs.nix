{ ... }:
{
  virtualisation.oci-containers.containers.scanservjs = {
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.scanservjs.rule" = "Host(`scan.svc.doofnet.uk`)";
      "traefik.http.services.scanservjs.loadbalancer.server.port" = "8080";
    };
    image = "sbs20/scanservjs:latest";
    volumes = [
      "/var/run/dbus:/var/run/dbus"
      "/mnt/nas-03/paperless/inbox:/var/lib/scanservjs/output"
      "/etc/scanservjs/config.local.js:/etc/scanservjs/config.local.js"
    ];
    extraOptions = [ "--privileged" ];
  };

  environment.etc = {
    "scanservjs/config.local.js".source = ./files/scanservjs/config.local.js;
  };
}
