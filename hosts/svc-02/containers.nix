{ lib, config, ... }:

let
  # Follows the same structure as virtualisation.oci-containers.containers
  containers = {

    # Unifi Controller
    unifi = {
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.unifi.rule" = "Host(`unifi.svc.doofnet.uk`)";
        "traefik.http.services.unifi.loadbalancer.server.port" = "8443";
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
      };
      extraOptions = [ "--network=host" ];
    };
  };

  # Extract local /srv/data paths from all volumes defined in any containers
  srvDataDirs = lib.unique (
    lib.flatten (
      lib.mapAttrsToList (
        _name: container:
        lib.filter (path: path != null) (
          map (
            volume:
            let
              localPath = lib.head (lib.splitString ":" volume);
            in
            if lib.hasPrefix "/srv/data/" localPath then localPath else null
          ) (container.volumes or [ ])
        )
      ) containers
    )
  );

in
{
  virtualisation.oci-containers.containers = containers;

  # Automatically create /srv/data directories from container definitions
  system.activationScripts.createContainerDirs = lib.stringAfter [ "var" ] ''
    ${lib.concatMapStringsSep "\n" (dir: ''
      if ! [ -f ${dir} ]; then mkdir -p "${dir}"; fi
      chmod u+rwX,g+rX,o+rX "${dir}"
    '') srvDataDirs}
  '';
}
