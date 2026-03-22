{
  pkgs,
  ...
}:
{
  virtualisation = {
    containers.enable = true;
    oci-containers.backend = "podman";
    podman = {
      enable = true;
      autoPrune.enable = true;
      dockerCompat = true;
      dockerSocket.enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  environment.systemPackages = with pkgs; [
    dive
    podman-tui
  ];

  # Suppress INFO-level Podman API access log entries (container discovery calls
  # from Traefik etc.) before they reach the journal.
  systemd.services.podman.serviceConfig.LogLevelMax = "warning";

  # Add podman as a supplementary group so Traefik can access the socket without
  # changing its primary group — created files will keep traefik group ownership.
  systemd.services.traefik.serviceConfig.SupplementaryGroups = [ "podman" ];

  # Configure Traefik to use Podman as a source
  services.traefik = {

    staticConfigOptions = {
      providers = {
        docker = {
          exposedByDefault = false;
          endpoint = "unix:///run/podman/podman.sock";
        };
      };
    };
  };

  # Enable scram auth from Podman subnet
  services.postgresql.authentication = pkgs.lib.mkAfter ''
    host all all 10.88.0.0/16 scram-sha-256
  '';
}
