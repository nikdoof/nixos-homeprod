{
  lib,
  ...
}:

{
  imports = [ ../../modules/doofnet/foundryvtt.nix ];

  # Make the FoundryVTT package available in pkgs
  nixpkgs.overlays = [
    (final: _: {
      foundryvtt = final.callPackage ../../packages/foundryvtt { };
    })
  ];

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "foundryvtt" ];

  doofnet.microvm = {
    enable = true;
    cid = 17;
    vlan = "101";
  };

  # Networking
  networking.hostName = "fvtt-01";
  networking.nameservers = [
    "10.101.1.2"
    "10.101.1.3"
    "2001:8b0:bd9:101::2"
    "2001:8b0:bd9:101::3"
  ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [
        "10.101.3.33/16"
        "2001:8b0:bd9:101::3:33/64"
        "fddd:d00f:dab0:101::3:33/64"
      ];
      Gateway = "10.101.1.1";
      IPv6AcceptRA = true;
      DHCP = "no";
      MulticastDNS = true;
    };
    dhcpV6Config.UseDelegatedPrefix = false;
  };

  networking.firewall.allowedTCPPorts = [ 30000 ];

  doofnet.foundryvtt = {
    enable = true;
    port = 30000;
    openFirewall = true;
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
