{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) types;
  cfg = config.doofnet.mailserver;

  mailboxDomains = lib.unique (
    cfg.domains
    ++ map (addr: builtins.elemAt (lib.splitString "@" addr) 1) (builtins.attrNames cfg.accounts)
  );

  aliasEntries = lib.flatten (
    lib.mapAttrsToList (
      account: info:
      map (
        alias:
        if builtins.match ".*@.*" alias != null then "${alias} ${account}" else "${alias}: ${account}"
      ) info.aliases
    ) cfg.accounts
  );

  extraAliasEntries = lib.mapAttrsToList (
    localpart: target: "${localpart}: ${target}"
  ) cfg.extraAliases;

  virtualAliasEntries = lib.mapAttrsToList (
    address: target: "${address} ${target}"
  ) cfg.virtualAliases;

  dovecotUserEntries = lib.mapAttrsToList (
    account: info: "${account}:${info.password}::::::"
  ) cfg.accounts;
in
{
  options.doofnet.mailserver = {
    domains = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Virtual domains beyond those derived from account email addresses";
    };

    accounts = lib.mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            password = lib.mkOption {
              type = types.str;
              default = "!";
              description = ''
                Dovecot password hash (SHA512-CRYPT) or "!" to disable login.
                Generate with: doveadm pw -s SHA512-CRYPT
              '';
            };
            aliases = lib.mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                Alias addresses that forward to this mailbox.
                Local-parts (e.g. "nikdoof") become system aliases.
                Full addresses (e.g. "hostmaster@doofnet.uk") become virtual aliases.
              '';
            };
          };
        }
      );
      default = { };
      description = "Mailbox accounts. Attribute name is the full email address.";
      example = {
        "andy@williams.id" = {
          password = "{SHA512-CRYPT}\$6\$...";
          aliases = [
            "andrew@williams.id"
            "hostmaster@doofnet.uk"
            "nikdoof"
          ];
        };
      };
    };

    extraAliases = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "System alias mappings (localpart -> target)";
      example = {
        root = "root-mail@m.tensixtyone.com";
      };
    };

    virtualAliases = lib.mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Virtual alias mappings (full address -> target)";
      example = {
        "root@int.doofnet.uk" = "root-mail@m.tensixtyone.com";
      };
    };

    sharedAccess = lib.mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = { };
      description = "Shared mailbox access grants (grantee -> list of target mailboxes)";
      example = {
        "andy@williams.id" = [
          "andy@2315media.com"
          "hello@2315media.com"
        ];
      };
    };

    virtualDomains = lib.mkOption {
      type = types.listOf types.str;
      readOnly = true;
      description = "Derived list of all virtual mailbox domains";
    };
  };

  config = {
    doofnet.mailserver.virtualDomains = mailboxDomains;

    services.postfix.extraAliases = lib.mkForce (
      lib.concatStringsSep "\n" (extraAliasEntries ++ aliasEntries) + "\n"
    );

    services.postfix.virtual = lib.mkForce (lib.concatStringsSep "\n" virtualAliasEntries + "\n");

    services.postfix.settings.main.virtual_mailbox_domains = lib.mkForce (
      lib.concatStringsSep " " mailboxDomains
    );

    services.dovecot2.extraConfig = lib.mkAfter ''
      passdb {
        driver = passwd-file
        args = /etc/dovecot/users
      }
    '';

    systemd.services.dovecot-passwd = lib.mkIf (cfg.accounts != { }) {
      description = "Build Dovecot passwd file";
      after = [ "network.target" ];
      before = [ "dovecot2.service" ];
      requiredBy = [ "dovecot2.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
                install -d -m 755 /etc/dovecot
                cat > /etc/dovecot/users << 'USERSOF'
        ${lib.concatStringsSep "\n" dovecotUserEntries}
        USERSOF
                chown vmail:vmail /etc/dovecot/users
                chmod 600 /etc/dovecot/users
      '';
    };

    services.opendkim.domains = lib.mkForce (lib.concatStringsSep "," mailboxDomains);

    # Postfix sender login maps — who can send as whom
    services.postfix.settings.main.smtpd_sender_login_maps = lib.mkIf (
      cfg.sharedAccess != { }
    ) "texthash:/etc/postfix/sender_login_maps";

    services.postfix.settings.main.smtpd_sender_restrictions = lib.mkIf (cfg.sharedAccess != { }) (
      lib.mkForce (
        lib.strings.concatMapStrings (x: x + ",") [
          "permit_mynetworks"
          "reject_non_fqdn_sender"
          "reject_unknown_sender_domain"
          "reject_sender_login_mismatch"
          "reject_rhsbl_sender dbl.spamhaus.org"
          "permit_sasl_authenticated"
          "permit"
        ]
      )
    );

    environment.etc."postfix/sender_login_maps" = lib.mkIf (cfg.sharedAccess != { }) {
      text =
        let
          allAccounts = builtins.attrNames cfg.accounts;
          whoCanSend =
            address:
            let
              self = [ address ];
              grantees = lib.flatten (
                lib.mapAttrsToList (
                  grantee: targets: lib.optional (builtins.elem address targets) grantee
                ) cfg.sharedAccess
              );
            in
            "${address} ${lib.concatStringsSep "," (self ++ grantees)}";
        in
        lib.concatStringsSep "\n" (map whoCanSend allAccounts) + "\n";
    };

    systemd.services.dovecot-shared-acls = lib.mkIf (cfg.sharedAccess != { }) {
      description = "Configure shared mailbox ACLs";
      after = [ "dovecot2.service" ];
      wantedBy = [ "dovecot2.service" ];
      bindsTo = [ "dovecot2.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = lib.concatStringsSep "\n" (
        lib.flatten (
          lib.mapAttrsToList (
            grantee: targets:
            map (
              target:
              let
                parts = lib.splitString "@" target;
                dom = builtins.elemAt parts 1;
                usr = builtins.elemAt parts 0;
              in
              ''
                install -d -o vmail -g vmail -m 750 /persist/vmail/${dom}/${usr}/Maildir/{new,cur,tmp}
                ${lib.getBin pkgs.dovecot}/bin/doveadm acl set -u '${target}' INBOX 'user=${grantee}' lookup read write write-seen write-deleted expunge || true
              ''
            ) targets
          ) cfg.sharedAccess
        )
      );
    };
  };
}
