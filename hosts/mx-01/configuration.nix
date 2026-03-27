{
  config,
  lib,
  pkgs,
  ...
}:
let
  domainName = "doofnet.uk";
in
{
  doofnet.microvm = {
    enable = true;
    cid = 12;
    vlan = "106";
  };

  # Networking
  networking.useDHCP = false;
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
  };

  networking.firewall = {
    allowedTCPPorts = [
      25
      465
      587
      993
    ];
  };

  doofnet.server = true;

  # Persist the ACME folder
  fileSystems."/var/lib/acme" = {
    device = "/persist/acme";
    options = [ "bind" ];
  };

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
          # set permission on dir
          ${pkgs.acl}/bin/setfacl -m \
          u:dovecot2:rx,u:postfix:rx \
          /var/lib/acme/${config.networking.hostName}.${config.networking.domain}

          # set permission on key file
          ${pkgs.acl}/bin/setfacl -m \
          u:dovecot2:r,u:postfix:r \
          /var/lib/acme/${config.networking.hostName}.${config.networking.domain}/*.pem
        '';
        reloadServices = [
          "postfix"
          "dovecot2"
          "opendmarc"
        ];
      };
    };
  };

  services.postfix = {
    enable = true;
    enableSmtp = true;
    enableSubmission = true;
    enableSubmissions = true;

    submissionOptions = {
      smtpd_tls_security_level = "encrypt";
      smtpd_sasl_auth_enable = "yes";
      smtpd_sasl_type = "dovecot";
      smtpd_sasl_path = "/var/spool/postfix/auth";
      smtpd_client_restrictions = "permit_sasl_authenticated,reject";
      milter_macro_daemon_name = "ORIGINATING";
    };

    submissionsOptions = {
      smtpd_tls_wrappermode = "yes";
      smtpd_tls_security_level = "encrypt";
      smtpd_sasl_auth_enable = "yes";
      smtpd_sasl_type = "dovecot";
      smtpd_sasl_path = "/var/spool/postfix/auth";
      smtpd_client_restrictions = "permit_sasl_authenticated,reject";
      milter_macro_daemon_name = "ORIGINATING";
    };

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

        mydestination = [
          "${config.networking.hostName}.${config.networking.domain}"
        ];

        # Milters: OpenDKIM (signing) + OpenDMARC (policy enforcement)
        milter_default_action = "accept";
        milter_protocol = "6";
        smtpd_milters = [
          "unix:${lib.removePrefix "local:" config.services.opendkim.socket}"
          "unix:${lib.removePrefix "local:" config.doofnet.opendmarc.socket}"
        ];
        non_smtpd_milters = "$smtpd_milters";

        # Dovecot
        virtual_mailbox_domains = "${config.networking.domain}";
        mailbox_transport = "lmtp:unix:/var/spool/postfix/dovecot-lmtp";
        virtual_transport = "lmtp:unix:/var/spool/postfix/dovecot-lmtp";
        smtpd_sasl_type = "dovecot";
        smtpd_sasl_path = "/var/spool/postfix/auth";
        smtpd_sasl_auth_enable = "yes";

        tls_medium_cipherlist = "AES128+EECDH:AES128+EDH";
        smtpd_tls_cert_file = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/fullchain.pem";
        smtpd_tls_key_file = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/key.pem";
        smtpd_tls_received_header = "yes";
        smtpd_tls_security_level = "may";
        smtpd_tls_auth_only = "yes";

        smtp_tls_note_starttls_offer = "yes";
        smtp_tls_security_level = "may";
        smtp_tls_cert_file = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/fullchain.pem";
        smtp_tls_key_file = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/key.pem";
        smtp_tls_loglevel = "1";

        smtpd_relay_restrictions = lib.strings.concatMapStrings (x: x + ",") [
          "permit_mynetworks"
          "permit_sasl_authenticated"
          "reject_unauth_destination"
        ];

        smtpd_helo_required = "yes";
        smtpd_helo_restrictions = lib.strings.concatMapStrings (x: x + ",") [
          "permit_mynetworks"
          "reject_non_fqdn_helo_hostname"
          "reject_invalid_helo_hostname"
          "permit"
        ];
        smtpd_sender_restrictions = lib.strings.concatMapStrings (x: x + ",") [
          "permit_mynetworks"
          "permit_sasl_authenticated"
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
    keyPath = "/persist/opendkim/keys";
    selector = builtins.hashString "sha1" "${config.services.postfix.settings.main.myhostname}";
    domains = config.networking.domain;
    inherit (config.services.postfix) user group;
    settings = {
      InternalHosts = lib.strings.concatMapStrings (
        x: x + ","
      ) config.services.postfix.settings.main.mynetworks;
    };
  };

  doofnet.opendmarc = {
    enable = true;
    inherit (config.services.postfix) user group;
    settings = {
      AuthservID = "${config.networking.hostName}.${config.networking.domain}";
      TrustedAuthservIDs = "${config.networking.hostName}.${config.networking.domain}";
      # Start in monitoring mode; set to true once SPF/DKIM are confirmed working
      RejectFailures = false;
      IgnoreAuthenticatedClients = true;
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

  age.secrets.dovecot = {
    file = ../../secrets/mx01DovecotPasswd.age;
    # -rw-------
    mode = "600";
    owner = "dovecot2";
    group = "dovecot2";
  };

  services.dovecot2 = {
    enable = true;

    # connection to postfix
    enableLmtp = true;
    enableImap = true;
    enablePop3 = false;
    enablePAM = false;

    sslServerCert = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/fullchain.pem";
    sslServerKey = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/key.pem";

    createMailUser = true;
    mailUser = "vmail";
    mailGroup = "vmail";

    # implement virtual users
    # https://doc.dovecot.org/2.3/configuration_manual/howto/simple_virtual_install/
    # store virtual mail under
    # /var/spool/mail/vmail/<DOMAIN>/<USER>/Maildir/
    mailLocation = "maildir:~/Maildir";

    mailboxes = {
      # use rfc standard https://apple.stackexchange.com/a/201346
      All = {
        auto = "create";
        autoexpunge = null;
        specialUse = "All";
      };
      Archive = {
        auto = "create";
        autoexpunge = null;
        specialUse = "Archive";
      };
      Drafts = {
        auto = "create";
        autoexpunge = null;
        specialUse = "Drafts";
      };
      Flagged = {
        auto = "create";
        autoexpunge = null;
        specialUse = "Flagged";
      };
      Junk = {
        auto = "create";
        autoexpunge = "60d";
        specialUse = "Junk";
      };
      Sent = {
        auto = "create";
        autoexpunge = null;
        specialUse = "Sent";
      };
      Trash = {
        auto = "create";
        autoexpunge = "60d";
        specialUse = "Trash";
      };
    };

    extraConfig = ''
      # force to use full user name plus domain name
      # for disambiguation
      auth_username_format = %Lu

      # Authentication configuration:
      auth_mechanisms = plain
      passdb {
        driver = passwd-file
        args = ${config.age.secrets.dovecot.path}
      }

      userdb {
        driver = static
        # the full e-mail address inside passwd-file is the username (%u)
        # user@example.com
        # %d for domain_name %n for user_name
        args = uid=vmail gid=vmail username_format=%u home=${config.users.users.vmail.home}/%d/%n
      }

      # connection to postfix via lmtp
      service lmtp {
       unix_listener /var/spool/postfix/dovecot-lmtp {
         mode = 0600
         user = postfix
         group = postfix
        }
      }
      service auth {
        unix_listener /var/spool/postfix/auth {
          mode = 0600
          user = postfix
          group = postfix
        }
      }
      service stats {
        inet_listener http {
          port = 9166
        }
      }

      # Metrics
      metric auth_success {
        filter = (event=auth_request_finished AND success=yes)
      }

      metric imap_command {
        filter = event=imap_command_finished
        group_by = cmd_name tagged_reply_state
      }

      metric smtp_command {
        filter = event=smtp_server_command_finished
        group_by = cmd_name status_code duration:exponential:1:5:10
      }

      metric mail_delivery {
        filter = event=mail_delivery_finished
        group_by = duration:exponential:1:5:10
      }
    '';

  };

  systemd.services.dovecot.serviceConfig.ExecStartPre =
    "${pkgs.coreutils}/bin/chown -R ${config.services.dovecot2.user}:${config.services.dovecot2.group} ${config.users.users.vmail.home}";

  services.prometheus.exporters.postfix = {
    enable = true;
    port = 9154;
    listenAddress = "127.0.0.1";
    systemd.enable = true;
  };

  environment.etc."alloy/conf.d/02-postfix.alloy".text = ''
    prometheus.scrape "postfix" {
      targets    = [{"__address__" = "localhost:9154"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "postfix"
    }
  '';

  environment.etc."alloy/conf.d/02-dovecot.alloy".text = ''
    prometheus.scrape "dovecot" {
      targets    = [{"__address__" = "localhost:9166"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "dovecot"
    }
  '';

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
