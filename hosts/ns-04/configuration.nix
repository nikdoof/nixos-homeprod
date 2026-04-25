{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];

  networking.hostName = "ns-04";
  networking.domain = "doofnet.uk";
  networking.search = [ "doofnet.uk" ];

  nix.settings = {
    substituters = [ "https://nix-community.cachix.org" ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "svc-02.int.doofnet.uk:7Q/KnURGp8h6kNbBle+StQNX/CST3mH9et5QqD4Lzs4="
    ];
    trusted-users = [ "@wheel" ];
  };

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
    publicOnly = true;
    # Reach ns-01 via the gateway's public NAT IP (81.187.48.147 -> 10.101.1.2)
    masters = [ "81.187.48.147" ];
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
