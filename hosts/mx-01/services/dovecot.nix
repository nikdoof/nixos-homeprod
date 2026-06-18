{
  config,
  lib,
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

  learnSpam = pkgs.writeText "learn-spam.sieve" ''
    require ["vnd.dovecot.pipe", "imapsieve", "environment", "variables"];

    if environment :matches "imap.mailbox" "*" {
      set "mailbox" "''${1}";
    }

    if string "''${mailbox}" "Junk" {
      pipe "rspamc-learn-spam" [];
    }
  '';

  learnHam = pkgs.writeText "learn-ham.sieve" ''
    require ["vnd.dovecot.pipe", "imapsieve", "environment", "variables"];

    if environment :matches "imap.mailbox" "*" {
      set "mailbox" "''${1}";
    }

    if not string "''${mailbox}" "Junk" {
      pipe "rspamc-learn-ham" [];
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

    sieve = {
      pipeBins = [
        (lib.getExe (
          pkgs.writeShellScriptBin "rspamc-learn-spam" ''
            exec ${pkgs.rspamd}/bin/rspamc -h 127.0.0.1:11334 learn_spam
          ''
        ))
        (lib.getExe (
          pkgs.writeShellScriptBin "rspamc-learn-ham" ''
            exec ${pkgs.rspamd}/bin/rspamc -h 127.0.0.1:11334 learn_ham
          ''
        ))
      ];
      scripts = {
        before = spamToJunk;
      };
    };

    imapsieve = {
      mailbox = [
        {
          name = "Junk";
          causes = [
            "COPY"
            "APPEND"
          ];
          before = learnSpam;
        }
        {
          name = "*";
          from = "Junk";
          causes = [ "COPY" ];
          before = learnHam;
        }
      ];
    };

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
        "sieve"
      ];
      perProtocol.imap.enable = [
        "imap_acl"
        "listescape"
        "imap_sieve"
      ];
    };

    pluginSettings = {
      fts = "flatcurve";
      fts_flatcurve = "default";
      fts_autoindex = "yes";
      acl = "vfile";
      acl_shared_dict = "file:${vmailHome}/shared-mailboxes.db";
      sieve = "~/.dovecot.sieve";
      sieve_dir = "~/sieve";
    };

    extraConfig = ''
      # TLS hardening - match Postfix's TLSv1.2+ requirement for IMAP clients
      ssl_min_protocol = TLSv1.2
      ssl_prefer_server_ciphers = yes

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
        location = maildir:%%h/Maildir:INDEX=~/shared/%%u
        subscriptions = yes
        list = yes
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
  environment.systemPackages = [ pkgs.dovecot-fts-flatcurve ];

}
