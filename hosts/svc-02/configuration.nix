_: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../hardware/prodesk-600-g3-dm.nix
    ../../modules/traefik.nix
    ../../modules/podman.nix
    ./services
  ];

  # Networking
  networking.useDHCP = false;
  networking.hostName = "svc-02";
  networking.nameservers = [
    "10.101.1.2"
    "2001:8b0:bd9:101::2"
    "10.101.1.3"
    "2001:8b0:bd9:101::3"
  ];
  networking.domain = "int.doofnet.uk";
  networking.search = [ "int.doofnet.uk" ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "eno1";
    networkConfig = {
      Address = [
        "10.101.3.21/16"
        "2001:8b0:bd9:101::21/64"
        "fddd:d00f:dab0:101::21/64"
      ];
      Gateway = "10.101.1.1";
      IPv6AcceptRA = true;
      DHCP = "no";
    };
  };

  programs.zsh.shellAliases = {
    # Shortcut to rebuild NS-01 from this host
    nrs-ns01 = "nixos-rebuild switch --refresh --flake github:nikdoof/nixos-homeprod#ns-01 --target-host ns-01 --no-reexec --sudo --ask-sudo-password";
  };

  doofnet.server = true;
  doofnet.cross_compile = true;
  doofnet.nfs.media = true;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
