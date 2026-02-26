{ lib, ... }:
{
  # Unifi Controller
  virtualisation.oci-containers.containers.unifi = {
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.unifi.rule" = "Host(`unifi.svc.doofnet.uk`)";
      "traefik.http.services.unifi.loadbalancer.server.port" = "8443";
      "traefik.http.services.unifi.loadbalancer.server.scheme" = "https";
      "traefik.http.services.unifi.loadbalancer.serversTransport" = "insecureTransport@file";
    };
    image = "jacobalberty/unifi:v10.0.162";
    volumes = [
      "/srv/data/unifi/data:/unifi:U"
    ];
    environment = {
      TZ = "UTC";
      RUNAS_UID0 = "false";
      UNIFI_UID = "999";
      UNIFI_GID = "999";
      JVM_INIT_HEAP_SIZE = "512M";
      JVM_MAX_HEAP_SIZE = "2048M";
      SYSTEM_IP = "10.101.3.21";
    };
    extraOptions = [ "--network=host" ];
  };

  networking.firewall = {
    allowedTCPPorts = [
      5671 # UXG Adpot
      8080 # Device & App
      8443 # UI
    ];
    allowedUDPPorts = [
      3478 # STUN
      10001 # Discovery
      1010 # Client fingerprint
      1900 # L2 Discovery
      5514 # Syslog
    ];
  };

  system.activationScripts.unifi = lib.stringAfter [ "var" ] ''
    if ! [ -f /srv/data/unifi ]; then mkdir -p "/srv/data/unifi"; fi
    chmod u+rwX,g+rX,o+rX "/srv/data/unifi"
  '';
}
