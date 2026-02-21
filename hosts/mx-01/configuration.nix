{
  config,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../hardware/esxi-vm.nix
    ../../modules/common.nix
    ../../modules/server.nix
  ];

  # Networking
  networking.useDHCP = false;
  networking.hostName = "mx-01";
  networking.nameservers = [
    "217.169.25.9"
    "2001:8b0:bd9:106::1"
  ];
  networking.domain = "doofnet.uk";
  networking.search = [ "doofnet.uk" ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "ens192";
    address = [
      "217.169.25.11/29"
      "2001:8b0:bd9:106::3/64"
    ];
    routes = [
      { Gateway = "217.169.25.9"; }
    ];
    networkConfig = {
      IPv6AcceptRA = true;
    };
  };

  services.postfix = {
    enable = true;

    hostname = "${config.networking.hostName}.${config.networking.domain}";
    domain = "${config.networking.domain}";

    networks = [
      "127.0.0.0/8"
      "[::ffff:127.0.0.0]/104"
      "[::1]/128"
      "10.101.0.0/16"
      "217.169.25.8/29"
      "[2001:8b0:bd9:101::]/64"
      "[2001:8b0:bd9:106::]/64"
    ];

    extraAliases = [
      "root: root-mail@m.tensixtyone.com"
      "inbox: paperless,household@williams.id"
      "nikdoof: andy@williams.id"
      "salkunh: jo@williams.id"
    ];

    virtual = [
      "root@int.${config.networking.domain} root-mail@m.tensixtyone.com"
      "root@lab.${config.networking.domain} root-mail@m.tensixtyone.com"
      "root@pub.${config.networking.domain} root-mail@m.tensixtyone.com"
      "root@dmz.${config.networking.domain} root-mail@m.tensixtyone.com"
    ];
  };

  services.opendkim = {
    enable = true;
    signingTable = [
      "${config.networking.domain} 20220504._domainkey.${config.networking.domain} ${config.networking.domain}"
    ];
    keyTable = [
      "20220504._domainkey.${config.networking.domain} ${config.networking.domain}:20220504:/etc/opendkim/keys/${config.networking.domain}/20220504.private"
    ];
    signingConfig = {
      "default" = {
        selector = "20220504";
        domain = "${config.networking.domain}";
        key = "/etc/opendkim/keys/${config.networking.domain}/default.private";
      };
    };
    trustedHosts = config.services.postfix.networks + [ "*.${config.networking.domain}" ];
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
