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

  # Configure Traefik to use Podman as a source
  services.traefik = {
    group = "podman";

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
    host all all 10.0.0.0/8 scram-sha-256
    host all all 2001:8b0:bd9:101::/64 scram-sha-256
  '';
}
