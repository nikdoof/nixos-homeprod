{
  pkgs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../hardware/prodesk-600-g3-dm.nix
    ../../hardware/coral-tpu-pcie.nix
    ../../modules/podman.nix
    ../../modules/traefik.nix
    ../../modules/postgresql.nix
    ./services
  ];

  # Networking
  networking.hostName = "svc-01";
  networking.nameservers = [
    "10.101.1.2"
    "2001:8b0:bd9:101::2"
    "10.101.1.3"
    "2001:8b0:bd9:101::3"
  ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "eno1";
    networkConfig = {
      Address = [
        "10.101.3.20/16"
        "2001:8b0:bd9:101::20/64"
        "fddd:d00f:dab0:101::20/64"
      ];
      Gateway = "10.101.1.1";
      IPv6AcceptRA = true;
      DHCP = "no";
    };
    dhcpV6Config.UseDelegatedPrefix = false;
  };

  doofnet.nfs = {
    media = true;
    paperless = true;
  };

  # Allow Private LAN access
  services.postgresql.authentication = pkgs.lib.mkAfter ''
    host all all 10.101.0.0/16 scram-sha-256
  '';

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
