{
  config,
  lib,
  pkgs,
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
    matchConfig.Name = "ens32";
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

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      25
      465
      587
    ];
  };

  age.secrets = {
    digitaloceanApiToken = {
      file = ../../secrets/digitalOceanApiToken.age;
      owner = "traefik";
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "certs@doofnet.uk";
    certs = {
      "${config.networking.hostName}.${config.networking.domain}" = {
        dnsProvider = "digitalocean";
        dnsResolver = "1.1.1.1:53";
        environmentFile = pkgs.writeText "acme-env" ''
          DO_AUTH_TOKEN_FILE=${config.age.secrets.digitaloceanApiToken.path}
        '';
        postRun = ''
          # set permission on dir
          ${pkgs.acl}/bin/setfacl -m \
          u:postfix:rx \
          /var/lib/acme/${config.networking.hostName}.${config.networking.domain}

          # set permission on key file
          ${pkgs.acl}/bin/setfacl -m \
          u:postfix:r \
          /var/lib/acme/${config.networking.hostName}.${config.networking.domain}/*.pem
        '';
        reloadServices = [ "postfix" ];
      };
    };
  };

  services.postfix = {
    enable = true;
    enableSmtp = true;

    settings = {
      main = {
        myhostname = "${config.networking.hostName}.${config.networking.domain}";
        mydomain = "${config.networking.domain}";

        mynetworks = [
          "127.0.0.0/8"
          "[::ffff:127.0.0.0]/104"
          "[::1]/128"
          "10.101.0.0/16"
          "217.169.25.8/29"
          "[2001:8b0:bd9:101::]/64"
          "[2001:8b0:bd9:106::]/64"
        ];

        # OpenDKIM
        milter_default_action = "accept";
        milter_protocol = "6";
        smtpd_milters = [
          "unix:${lib.removePrefix "local:" config.services.opendkim.socket}"
        ];
        non_smtpd_milters = "$smtpd_milters";

        tls_medium_cipherlist = "AES128+EECDH:AES128+EDH";
        smtpd_tls_cert_file = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/cert.pem";
        smtpd_tls_key_file = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/privkey.pem";
        smtpd_tls_received_header = "yes";
        smtpd_tls_security_level = "may";
        smtpd_tls_auth_only = "yes";

        smtp_tls_note_starttls_offer = "yes";
        smtp_tls_security_level = "may";

        smtpd_helo_required = "yes";
        smtpd_helo_restrictions = lib.strings.concatMapStrings (x: x + ",") [
          "permit_mynetworks"
          "reject_non_fqdn_helo_hostname"
          "reject_invalid_helo_hostname"
          "permit"
        ];
        smtpd_sender_restrictions = lib.strings.concatMapStrings (x: x + ",") [
          "permit_mynetworks"
          "reject_non_fqdn_sender"
          "reject_unknown_sender_domain"
          "permit"
        ];
        smtpd_recipient_restrictions = lib.strings.concatMapStrings (x: x + ",") [
          "reject_invalid_hostname"
          "reject_unknown_recipient_domain"
          "reject_unauth_pipelining"
          "permit_mynetworks"
          "reject_non_fqdn_recipient"
          "reject_unauth_destination"
          "reject_rbl_client dnsbl.dronebl.org"
          "reject_rbl_client zen.spamhaus.org"
          "reject_rbl_client bl.spamcop.net"
          "reject_rbl_client dnsbl.sorbs.net"
          "reject_rbl_client cbl.abuseat.org"
          "reject_rbl_client b.barracudacentral.org"
          "reject_rbl_client dnsbl-1.uceprotect.net"
          "permit"
        ];
      };
    };

    extraAliases = lib.strings.concatMapStrings (x: x + "\n") [
      "root: root-mail@m.tensixtyone.com"
      "inbox: paperless,household@williams.id"
      "nikdoof: andy@williams.id"
      "salkunh: jo@williams.id"
    ];

    virtual = lib.strings.concatMapStrings (x: x + "\n") [
      "root@int.${config.networking.domain} root-mail@m.tensixtyone.com"
      "root@lab.${config.networking.domain} root-mail@m.tensixtyone.com"
      "root@pub.${config.networking.domain} root-mail@m.tensixtyone.com"
      "root@dmz.${config.networking.domain} root-mail@m.tensixtyone.com"
    ];
  };

  services.opendkim = {
    enable = true;
    selector = builtins.hashString "sha1" "${config.services.postfix.settings.main.myhostname}";
    domains = config.networking.domain;
    inherit (config.services.postfix) user group;
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
