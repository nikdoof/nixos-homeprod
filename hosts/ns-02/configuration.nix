{
  inputs,
  config,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ../../modules/doofnet
    ../../modules/bind
    inputs.microvm.nixosModules.microvm
  ];

  microvm = {
    hypervisor = "qemu";
    vcpu = 2;
    mem = 1024;
    interfaces = [
      {
        type = "tap";
        tap.vhost = true;
        id = "vm-ns-02";
        mac = "02:00:00:00:00:01";
      }
    ];
    shares = [
      {
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        tag = "ro-store";
        proto = "virtiofs";
      }
    ];
  };

  # Networking
  networking.useDHCP = false;
  networking.hostName = "ns-02";
  networking.nameservers = [
    "127.0.0.1"
  ];
  networking.domain = "int.doofnet.uk";
  networking.search = [ "int.doofnet.uk" ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    address = [
      "10.101.4.2/24"
      "2001:8b0:bd9:101:4:2/64"
      "fddd:d00f:dab0:101:4:2/64"
    ];
    routes = [
      { Gateway = "10.101.1.1"; }
    ];
    networkConfig = {
      IPv6AcceptRA = true;
    };
  };

  doofnet.server = true;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
