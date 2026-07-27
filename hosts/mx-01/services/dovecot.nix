{
  config,
  pkgs,
  ...
}:

let
  postfixSpoolDir = "/var/spool/postfix";
  vmailHome = "/persist/vmail";

  spamToJunk = pkgs.writeText "spam-to-junk.sieve" ''
    require ["fileinto", "mailbox"];

    if header :contains "X-Spam-Level" "*****" {
      fileinto :create "Junk";
      stop;
    }
  '';

  sieveDir = "/var/lib/dovecot/sieve";
in
{
  services.dovecot2 = {
    enable = true;
    package = pkgs.dovecot;

    enablePAM = false;
    createMailUser = true;

    settings = {
      dovecot_config_version = "2.4.4";
      dovecot_storage_version = "2.4.4";

      protocols = [
        "imap"
        "lmtp"
        "sieve"
      ];

      ssl_server_cert_file = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/fullchain.pem";
      ssl_server_key_file = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/key.pem";

      mail_driver = "maildir";
      mail_path = "~/Maildir";

      ssl_min_protocol = "TLSv1.2";
      ssl_server_prefer_ciphers = "server";

      mail_plugins = {
        acl = true;
        fts = true;
        fts_flatcurve = true;
        quota = true;
        mail_compress = true;
      };

      auth_username_format = "%{user | lower}";

      # IMAP METADATA (RFC 5464) — per-mailbox and per-server annotations
      # METADATA requires a mail_attribute dict for storage.
      mail_attribute."dict file".path = "%{home}/Maildir/dovecot-attributes";

      "protocol imap" = {
        mail_plugins = {
          imap_acl = true;
          imap_quota = true;
        };
        imap_metadata = true;
        imap_literal_minus = true;
      };

      "protocol lmtp" = {
        mail_plugins = {
          sieve = true;
        };
      };

      "namespace inbox" = {
        inbox = true;
        separator = "/";
        mailbox = [
          {
            _section.name = "All";
            auto = "create";
            special_use = "\\All";
          }
          {
            _section.name = "Archive";
            auto = "create";
            special_use = "\\Archive";
          }
          {
            _section.name = "Drafts";
            auto = "create";
            special_use = "\\Drafts";
          }
          {
            _section.name = "Flagged";
            auto = "create";
            special_use = "\\Flagged";
          }
          {
            _section.name = "Junk";
            auto = "create";
            autoexpunge = "60d";
            special_use = "\\Junk";
          }
          {
            _section.name = "Sent";
            auto = "create";
            special_use = "\\Sent";
          }
          {
            _section.name = "Trash";
            auto = "create";
            autoexpunge = "60d";
            special_use = "\\Trash";
          }
        ];
      };

      "namespace shared" = {
        separator = "/";
        type = "shared";
        prefix = "Shared/%{owner_user}/";
        mail_driver = "maildir";
        mail_path = "%{owner_home}/Maildir";
        mail_index_path = "~/Maildir/shared/%{owner_user}";
        subscriptions = true;
        list = "children";
      };

      # ManageSieve (RFC 5804) — remote Sieve script management
      "service managesieve-login"."inet_listener sieve" = {
        port = 4190;
        ssl = true;
      };

      # connection to postfix via lmtp
      "service lmtp"."unix_listener ${postfixSpoolDir}/dovecot-lmtp" = {
        mode = "0600";
        user = "postfix";
        group = "postfix";
      };

      "service auth" = {
        user = "root";
        "unix_listener ${postfixSpoolDir}/auth" = {
          mode = "0600";
          user = "postfix";
          group = "postfix";
        };
      };

      "service stats"."inet_listener http" = {
        port = 9166;
      };

      auth_mechanisms = [
        "plain"
        "login"
      ];

      "userdb static" = {
        fields = {
          uid = "vmail";
          gid = "vmail";
          home = "${vmailHome}/%{user | domain}/%{user | username}";
        };
      };

      # Plugin settings — global in Dovecot 2.4 (plugin {} section removed)
      fts_autoindex = "yes";
      language_filters = {
        normalizer_icu = true;
        snowball = true;
        stopwords = true;
      };

      "language en" = {
        language_default = true;
      };
      "language de" = { };

      acl_driver = "vfile";
      acl_sharing_map = {
        "dict file" = {
          path = "${vmailHome}/shared-mailboxes.db";
        };
      };

      "fts flatcurve" = { };

      quota_storage_size = "10G";

      "quota \"User quota\"" = {
        quota_driver = "maildir";
      };

      "sieve_script before_spam" = {
        sieve_script_type = "before";
        sieve_script_path = "${sieveDir}/spam-to-junk.sieve";
        sieve_script_name = "spam-to-junk";
      };

      # Metrics
      "metric auth_success".filter = "(event=auth_request_finished AND success=yes)";
      "metric imap_command" = {
        filter = "event=imap_command_finished";
        "group_by cmd_name"."method discrete" = { };
        "group_by tagged_reply_state"."method discrete" = { };
      };
      "metric smtp_command" = {
        filter = "event=smtp_server_command_finished";
        "group_by cmd_name"."method discrete" = { };
        "group_by status_code"."method discrete" = { };
        "group_by duration"."method exponential" = {
          min_magnitude = 1;
          max_magnitude = 5;
          base = 10;
        };
      };
      "metric mail_delivery" = {
        filter = "event=mail_delivery_finished";
        "group_by duration"."method exponential" = {
          min_magnitude = 1;
          max_magnitude = 5;
          base = 10;
        };
      };
    };
  };

  # Copy Sieve script from Nix store to writable location so Dovecot can
  # write the compiled .svbin binary alongside it (Nix store is read-only).
  systemd.tmpfiles.rules = [
    "d ${sieveDir} 0750 dovecot2 dovecot2 -"
    "C ${sieveDir}/spam-to-junk.sieve ${spamToJunk} - - -"
  ];

  # Ensure vmail owns its home before Dovecot starts
  systemd.services.dovecot.serviceConfig.ExecStartPre =
    "${pkgs.coreutils}/bin/chown -R vmail:vmail ${vmailHome}";

  # Allow Dovecot to write auth/LMTP sockets in Postfix spool dir
  systemd.services.dovecot.serviceConfig.ReadWritePaths = [
    "/var/spool/postfix"
  ];

  # Wait for ACME cert before starting dovecot
  systemd.services.dovecot.requires = [
    "acme-${config.networking.hostName}.${config.networking.domain}.service"
  ];
  systemd.services.dovecot.after = [
    "acme-${config.networking.hostName}.${config.networking.domain}.service"
  ];

  environment.systemPackages = [
    pkgs.dovecot_pigeonhole
  ];
}
