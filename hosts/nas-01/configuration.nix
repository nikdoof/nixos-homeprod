_: {
  imports = [
    ./hardware-configuration.nix
    ./services/monitoring.nix
  ];

  # Networking
  networking.hostId = "18e8a744";
  networking.hostName = "nas-01";
  networking.nameservers = [
    "10.101.1.2"
    "2001:8b0:bd9:101::2"
    "10.101.1.3"
    "2001:8b0:bd9:101::3"
  ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [
        "10.101.3.16/16"
        "2001:8b0:bd9:101::16/64"
        "fddd:d00f:dab0:101::3:16/64"
        "fddd:d00f:dab0:101::16/64"
      ];
      Gateway = "10.101.1.1";
      IPv6AcceptRA = true;
      DHCP = "no";
      MulticastDNS = true;
    };
    dhcpV6Config.UseDelegatedPrefix = false;
  };

  # NFS
  services.nfs.server = {
    enable = true;
  };
  networking.firewall.allowedTCPPorts = [ 2049 ];

  # Samba
  services.samba = {
    enable = true;
    settings = {
      global = {
        "usershare path" = "/var/lib/samba/usershares";
        "usershare max shares" = "100";
        "usershare allow guests" = "yes";
        "usershare owner only" = "no";
      };
    };
    openFirewall = true;
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/samba/usershares 1777 root root - -"
  ];

  # ZFS
  boot.zfs.extraPools = [
    "ssd-mirror"
    "tank01"
    "tank02"
    "media"
  ];
  services.zfs.autoScrub.enable = true;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
