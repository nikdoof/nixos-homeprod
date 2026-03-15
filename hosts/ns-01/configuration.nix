{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../hardware/raspberry-pi-3.nix
    # Required to produce an SD card image for the Pi.
    # modulesPath is a built-in specialArg provided by nixpkgs.lib.nixosSystem
    # pointing at the nixpkgs modules directory — no need to pass nixpkgs itself.
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
  ];

  # nix-community cache is needed to pull pre-built aarch64 binaries
  # (e.g. dns.nix) when deploying to this host from an x86_64 builder.
  nix.settings = {
    substituters = [ "https://nix-community.cachix.org" ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # Networking
  networking.useDHCP = false;
  networking.hostName = "ns-01";
  networking.nameservers = [
    "127.0.0.1"
    "10.101.1.2"
    "10.101.1.3"
  ];
  networking.domain = "int.doofnet.uk";
  networking.search = [ "int.doofnet.uk" ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [
        "10.101.1.2/16"
        "2001:8b0:bd9:101::2/64"
        "fddd:d00f:dab0:101::2/64"
      ];
      Gateway = "10.101.1.1";
      IPv6AcceptRA = true;
      DHCP = "no";
    };
  };
  networking.wireless = {
    enable = lib.mkForce false;
  };

  # We need to do remote rebuilds, and its just easier to connect as root
  services.openssh.settings.PermitRootLogin = lib.mkForce "yes";

  doofnet.server = true;

  doofnet.bind = {
    enable = true;
    mode = "primary";
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
