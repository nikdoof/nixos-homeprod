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
}
