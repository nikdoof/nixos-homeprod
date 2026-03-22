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

  # Allow Private LAN access
  services.postgresql.authentication = pkgs.lib.mkAfter ''
    host all all 10.101.0.0/16 scram-sha-256
  '';

  services.prometheus.exporters.smartctl = {
    enable = true;
    port = 9633;
    listenAddress = "127.0.0.1";
  };

  environment.etc."alloy/conf.d/02-smartctl.alloy".text = ''
    prometheus.scrape "smartctl" {
      targets    = [{"__address__" = "localhost:9633"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "smartctl"
    }
  '';

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
