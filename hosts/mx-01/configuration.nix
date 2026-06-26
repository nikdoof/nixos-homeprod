{
  config,
  pkgs,
  ...
}:
let
  domainName = "doofnet.uk";
in
{
  imports = [ ./services ];

  doofnet.microvm = {
    enable = true;
    cid = 12;
    vlan = "106";
    mem = 2560;
  };

  services.redis = {
    package = pkgs.valkey;
    servers.rspamd = {
      enable = true;
      port = 6379;
      bind = "127.0.0.1";
      appendOnly = true;
      save = [
        [
          900
          1
        ]
        [
          300
          10
        ]
        [
          60
          10000
        ]
      ];
      logLevel = "notice";
    };
  };

  # Ensure /persist/valkey exists for the bind mount below.
  # systemd-tmpfiles runs before local-fs.target (which processes mount units),
  # and the virtiofs /persist mount is available from early boot.
  systemd.tmpfiles.rules = [
    "d /persist/valkey 0700 redis-rspamd redis-rspamd -"
  ];

  # Persist Valkey data across rebuilds (systemd's ProtectSystem=strict blocks
  # writes to non-standard paths, so bind mount over the default StateDirectory).
  fileSystems."/var/lib/redis-rspamd" = {
    device = "/persist/valkey";
    options = [ "bind" ];
  };

  # Networking
  networking.hostName = "mx-01";
  networking.nameservers = [
    "217.169.25.9"
    "2001:8b0:bd9:106::1"
  ];
  networking.domain = domainName;
  networking.search = [ domainName ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
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
    dhcpV6Config.UseDelegatedPrefix = false;
  };

  networking.firewall = {
    allowedTCPPorts = [
      25
      465
      587
      993
      4190
    ];
  };

  doofnet.mailserver = {
    domains = [ "dimension.sh" ];

    accounts = {
      # Humans
      "nikdoof@doofnet.uk" = {
        password = "{SHA512-CRYPT}$6$vxZqxWy4ReW.c22G$UJkC9IxlcMdNOMBDz9N8hMsJTVNEUfJ1fcSIed7qAcBNYMGkr/DzuLHM/8jycLBwAm429f56.CuYnQHh.UwN01";
      };

      "salkunh@doofnet.uk" = {
        password = "!";
      };

      # Shared mailbox
      "dmarc-reports@doofnet.uk" = {
        password = "!";
      };
      "paperless@doofnet.uk" = {
        password = "{SHA512-CRYPT}$6$5PeSPUO39jE4or0v$LL3DIOyDpzXcHC5UScNRgy0gQ2kxxxQX88aO1KV3Zl7GpHPArDwngpLhb77ytNMKt4iQtT81uH6npHZgdWmUQ1";
      };
      "hello@nikdoof.com" = {
        password = "!";
      };
      "hello@intellectops.com" = {
        password = "!";
      };
    };

    extraAliases = {
      root = "root-mail@m.tensixtyone.com";
      inbox = "paperless@doofnet.uk,household@williams.id";
    };

    virtualAliases = {
      "root@int.doofnet.uk" = "root-mail@m.tensixtyone.com";
      "root@lab.doofnet.uk" = "root-mail@m.tensixtyone.com";
      "root@pub.doofnet.uk" = "root-mail@m.tensixtyone.com";
      "root@dmz.doofnet.uk" = "root-mail@m.tensixtyone.com";

      "salkunh@dimension.sh" = "salkunh@doofnet.uk";

      "nikdoof@dimension.sh" = "nikdoof@doofnet.uk";
      "nikdoof@nikdoof.com" = "nikdoof@doofnet.uk";
      "nik_doof@nikdoof.com" = "nikdoof@doofnet.uk";
      "andy@nikdoof.com" = "nikdoof@doofnet.uk";

      "reply@nikdoof.com" = "hello@nikdoof.com";
    };

    sharedAccess = {
      "nikdoof@doofnet.uk" = [
        "paperless@doofnet.uk"
        "dmarc-reports@doofnet.uk"
        "hello@nikdoof.com"
        "hello@intellectops.com"
      ];
    };
  };

  doofnet.fail2ban.enable = true;
  doofnet.fail2ban.jails.dovecot = true;

  age.secrets = {
    digitaloceanApiToken = {
      file = ../../secrets/digitalOceanApiToken.age;
      owner = "acme";
    };
  };

  security.acme = {
    certs = {
      "${config.networking.hostName}.${config.networking.domain}" = {
        dnsProvider = "digitalocean";
        dnsResolver = "1.1.1.1:53";
        environmentFile = pkgs.writeText "acme-env" ''
          DO_AUTH_TOKEN_FILE=${config.age.secrets.digitaloceanApiToken.path}
        '';
        postRun = ''
          ${pkgs.acl}/bin/setfacl -m \
          u:dovecot2:rx,u:postfix:rx \
          /var/lib/acme/${config.networking.hostName}.${config.networking.domain}

          ${pkgs.acl}/bin/setfacl -m \
          u:dovecot2:r,u:postfix:r \
          /var/lib/acme/${config.networking.hostName}.${config.networking.domain}/*.pem
        '';
        reloadServices = [
          "postfix"
          "dovecot2"
          "rspamd"
        ];
      };
    };
  };

  users.groups.vmail = { };
  users.users."vmail" = {
    createHome = true;
    home = "/persist/vmail";
    isSystemUser = true;
    group = "vmail";
  };
  users.users."postfix" = {
    createHome = true;
    home = "/var/spool/postfix";
  };

  system.stateVersion = "25.11";
}
