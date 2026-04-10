{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];

  networking.hostName = "ns-03";
  networking.domain = "doofnet.uk";
  networking.search = [ "doofnet.uk" ];

  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      DHCP = "yes";
    };
  };

  doofnet.bind = {
    enable = true;
    mode = "secondary";
    # Reach ns-01 via the gateway's public NAT IP (81.187.48.147 -> 10.101.1.2)
    masters = [ "81.187.48.147" ];
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
