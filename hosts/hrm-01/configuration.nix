{
  config,
  ...
}:
{

  doofnet.microvm = {
    enable = true;
    cid = 16;
    vlan = "101";
  };

  # Networking
  networking.hostName = "hrm-01";
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
        "10.101.3.32/16"
        "2001:8b0:bd9:101::3:32/64"
        "fddd:d00f:dab0:101::3:32/64"
      ];
      Gateway = "10.101.1.1";
      IPv6AcceptRA = true;
      DHCP = "no";
    };
    dhcpV6Config.UseDelegatedPrefix = false;
  };

  virtualisation.docker.enable = false;

  age.secrets = {
    hermesEnv = {
      file = ../../secrets/hermesEnv.age;
    };
  };

  services.hermes-agent = {
    enable = true;
    settings.model.default = "openrouter/owl-alpha";

    environmentFiles = [
      config.age.secrets.hermesEnv.path
    ];

    container.enable = true;
    container.backend = "podman";
    container.hostUsers = [ "nikdoof" ];
    addToSystemPackages = true;

    extraDependencyGroups = [ "messaging" ];
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
