{
  config,
  pkgs,
  ...
}:

let
  postfixSpoolDir = config.users.users.postfix.home;
  vmailHome = config.users.users.vmail.home;

  spamToJunk = pkgs.writeText "spam-to-junk.sieve" ''
    require ["fileinto", "mailbox"];

    if header :contains "X-Spam-Level" "*****" {
      fileinto :create "Junk";
      stop;
    }
  '';
in
{
  services.dovecot2 = {
    enable = true;

    enableLmtp = true;
    enableImap = true;
    enablePop3 = false;
    enablePAM = false;

    sslServerCert = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/fullchain.pem";
    sslServerKey = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/key.pem";

    createMailUser = true;
    mailUser = "vmail";
    mailGroup = "vmail";

    mailLocation = "maildir:~/Maildir";

    mailboxes = {
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

    mailPlugins = {
      globally.enable = [
        "acl"
        "fts"
        "fts_flatcurve"
        "quota"
        "zlib"
      ];
      perProtocol.imap.enable = [
        "imap_acl"
        "imap_quota"
        "imap_zlib"
        "listescape"
      ];
      perProtocol.lmtp.enable = [
        "sieve"
      ];
    };

    pluginSettings = {
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
      sieve_before = "${spamToJunk}";
    };

    extraConfig = ''
      # TLS hardening - match Postfix's TLSv1.2+ requirement for IMAP clients
      ssl_min_protocol = TLSv1.2
      ssl_prefer_server_ciphers = yes

      # IMAP METADATA (RFC 5464) — per-mailbox and per-server annotations
      mail_attribute_dict = file:%h/Maildir/dovecot-attributes

      protocol imap {
        imap_metadata = yes
        imap_literal_minus = yes
        imap_id_log = *
      }

      # force to use full user name plus domain name
      # for disambiguation
      auth_username_format = %Lu

      # Authentication configuration:
      auth_mechanisms = plain login

      userdb {
        driver = static
        args = uid=vmail gid=vmail username_format=%u home=${vmailHome}/%d/%n
      }

      # Explicitly match separators for all list=yes namespaces
      namespace inbox {
        separator = /
      }

      namespace shared {
        separator = /
        type = shared
        prefix = Shared/%%u/
        location = maildir:%%h/Maildir:INDEX=~/Maildir/shared/%%u
        subscriptions = yes
        list = children
      }

      # connection to postfix via lmtp
      service lmtp {
       unix_listener ${postfixSpoolDir}/dovecot-lmtp {
         mode = 0600
         user = postfix
         group = postfix
        }
      }
      service auth {
        unix_listener ${postfixSpoolDir}/auth {
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

  # Ensure vmail owns its home before Dovecot starts
  systemd.services.dovecot.serviceConfig.ExecStartPre =
    "${pkgs.coreutils}/bin/chown -R ${config.services.dovecot2.mailUser}:${config.services.dovecot2.mailGroup} ${vmailHome}";

  # Dovecot FTS flatcurve plugin for full-text search
  environment.systemPackages = [
    pkgs.dovecot-fts-flatcurve
    pkgs.dovecot_pigeonhole
  ];

}
