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
      ];

      ssl_cert = "</var/lib/acme/${config.networking.hostName}.${config.networking.domain}/fullchain.pem>";
      ssl_key = "</var/lib/acme/${config.networking.hostName}.${config.networking.domain}/key.pem>";

      disable_plaintext_auth = true;

      mail_location = "maildir:~/Maildir";

      ssl_min_protocol = "TLSv1.2";
      ssl_prefer_server_ciphers = true;

      mail_attribute_dict = "file:%h/Maildir/dovecot-attributes";

      mail_plugins = {
        acl = true;
        fts = true;
        fts_flatcurve = true;
        quota = true;
        zlib = true;
      };

      auth_username_format = "%Lu";

      # IMAP METADATA (RFC 5464) — per-mailbox and per-server annotations
      "protocol imap" = {
        mail_plugins = {
          imap_acl = true;
          imap_quota = true;
          imap_zlib = true;
          listescape = true;
        };
        imap_metadata = true;
        imap_literal_minus = true;
        imap_id_log = "*";
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
        prefix = "Shared/%%u/";
        location = "maildir:%%h/Maildir:INDEX=~/Maildir/shared/%%u";
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

      "userdb" = {
        driver = "static";
        args = "uid=vmail gid=vmail username_format=%u home=${vmailHome}/%d/%n";
      };

      plugin = {
        fts = "flatcurve";
        fts_autoindex = "yes";
        fts_languages = "en de";
        fts_tokenizers = "generic email-address";
        fts_tokenizer_generic = "algorithm=simple maxlen=30";
        fts_tokenizer_email_address = "maxlen=100";
        fts_filters = "normalizer-icu snowball stopwords";
        fts_filters_en = "lowercase snowball english-possessive stopwords";
        acl = "vfile";
        acl_shared_dict = "file:${vmailHome}/shared-mailboxes.db";
        quota = "maildir:User quota";
        quota_vsizes = "yes";
        quota_rule = "*:storage=10G";
        sieve = "~/.dovecot.sieve";
        sieve_dir = "~/sieve";
        sieve_before = "${sieveDir}/spam-to-junk.sieve";
        sieve_global_extensions = [
          "+fileinto"
          "+mailbox"
        ];
      };

      # Metrics
      "metric auth_success".filter = "(event=auth_request_finished AND success=yes)";
      "metric imap_command" = {
        filter = "event=imap_command_finished";
        group_by = "cmd_name tagged_reply_state";
      };
      "metric smtp_command" = {
        filter = "event=smtp_server_command_finished";
        group_by = "cmd_name status_code duration:exponential:1:5:10";
      };
      "metric mail_delivery" = {
        filter = "event=mail_delivery_finished";
        group_by = "duration:exponential:1:5:10";
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
