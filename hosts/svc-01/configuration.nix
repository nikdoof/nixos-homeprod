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
    ../../modules/doofnet
    ../../modules/podman.nix
    ../../modules/traefik.nix
    ../../modules/postgresql.nix
    ./services
  ];

  # Networking
  networking.useDHCP = false;
  networking.hostName = "svc-01"; # Define your hostname.
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
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
  };

  doofnet.server = true;
  doofnet.nfs = {
    media = true;
    paperless = true;
  };

  services.postgresql = {
    authentication = pkgs.lib.mkOverride 10 ''
      local all all trust
      host sameuser all 127.0.0.1/32 scram-sha-256
      host sameuser all ::1/128 scram-sha-256
      host all all 10.0.0.0/8 scram-sha-256
      host all all 2001:8b0:bd9:101::/64 scram-sha-256
    '';
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
