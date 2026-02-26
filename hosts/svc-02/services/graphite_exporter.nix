{ ... }:
{
  services.prometheus.exporters = {
    graphite = {
      enable = true;
      openFirewall = true;
      mappingSettings = builtins.fromJSON (builtins.readFile ./files/truenas_mapping.json);
    };
  };

  # The graphite incoming port
  networking.firewall = {
    allowedTCPPorts = [
      9109
    ];
    allowedUDPPorts = [
      9109
    ];
  };
}
