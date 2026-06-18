{
  config,
  lib,
  ...
}:

let
  postfixSpoolDir = config.users.users.postfix.home;
in
{
  services.postfix = {
    enable = true;
    enableSmtp = true;
    enableSubmission = true;
    enableSubmissions = true;

    submissionOptions = {
      smtpd_tls_security_level = "encrypt";
      smtpd_sasl_auth_enable = "yes";
      smtpd_sasl_type = "dovecot";
      smtpd_sasl_path = "${postfixSpoolDir}/auth";
      smtpd_client_restrictions = "permit_sasl_authenticated,reject";
      milter_macro_daemon_name = "ORIGINATING";
    };

    submissionsOptions = {
      smtpd_tls_wrappermode = "yes";
      smtpd_tls_security_level = "encrypt";
      smtpd_sasl_auth_enable = "yes";
      smtpd_sasl_type = "dovecot";
      smtpd_sasl_path = "${postfixSpoolDir}/auth";
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

        # Milter: Rspamd (spam, DKIM, DMARC, SPF)
        milter_default_action = "accept";
        milter_protocol = "6";
        smtpd_milters = [
          "inet:${(builtins.head config.services.rspamd.workers.proxy.bindSockets).socket}"
        ];
        non_smtpd_milters = "$smtpd_milters";

        # Dovecot
        mailbox_transport = "lmtp:unix:${postfixSpoolDir}/dovecot-lmtp";
        virtual_transport = "lmtp:unix:${postfixSpoolDir}/dovecot-lmtp";
        smtpd_sasl_type = "dovecot";
        smtpd_sasl_path = "${postfixSpoolDir}/auth";

        # Inbound TLS (smtpd)
        smtpd_tls_cert_file = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/fullchain.pem";
        smtpd_tls_key_file = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/key.pem";
        smtpd_tls_received_header = "yes";
        smtpd_tls_security_level = "may";
        smtpd_tls_auth_only = "yes";
        smtpd_tls_protocols = "!SSLv2, !SSLv3, !TLSv1, !TLSv1.1";
        smtpd_tls_mandatory_protocols = "!SSLv2, !SSLv3, !TLSv1, !TLSv1.1";
        smtpd_tls_mandatory_ciphers = "high";
        smtpd_tls_loglevel = "2";

        # Outbound TLS (smtp client)
        # DANE: upgrade to DNSSEC-verified TLS for servers publishing TLSA records,
        # fall back to opportunistic TLS for those that don't.
        smtp_tls_security_level = "dane";
        smtp_dns_support_level = "dnssec";
        smtp_tls_cert_file = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/fullchain.pem";
        smtp_tls_key_file = "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/key.pem";
        smtp_tls_protocols = "!SSLv2, !SSLv3, !TLSv1, !TLSv1.1";
        smtp_tls_mandatory_protocols = "!SSLv2, !SSLv3, !TLSv1, !TLSv1.1";
        smtp_tls_loglevel = "1";
        smtp_tls_fingerprint_digest = "sha256";
        smtp_tls_session_cache_database = "btree:/var/lib/postfix/data/smtp_scache";
        smtp_bind_address6 = "2001:8b0:bd9:106::3";
        smtpd_tls_session_cache_database = "btree:/var/lib/postfix/data/smtpd_scache";

        # SMTP request smuggling protection (CVE-2023-51764)
        smtpd_forbid_bare_newline = "yes";
        smtpd_forbid_bare_newline_exclusions = "$mynetworks";

        # Disable VRFY command to prevent recipient enumeration
        disable_vrfy_command = "yes";

        smtpd_relay_restrictions = lib.strings.concatMapStrings (x: x + ",") [
          "permit_mynetworks"
          "permit_sasl_authenticated"
          "reject_unauth_destination"
        ];

        # Rate limiting - protect against compromised accounts/hosts flooding outbound
        anvil_rate_time_unit = "60s";
        smtpd_client_connection_rate_limit = "10";
        smtpd_client_message_rate_limit = "100";
        smtpd_client_recipient_rate_limit = "100";
        smtpd_client_auth_rate_limit = "10";

        # Bounce and error management - high bounce rates trigger blacklisting
        bounce_queue_lifetime = "1d";
        smtpd_soft_error_limit = "3";
        smtpd_hard_error_limit = "10";
        smtpd_error_sleep_time = "1s";

        # Postscreen - pre-screen inbound SMTP connections before they reach smtpd
        postscreen_access_list = "permit_mynetworks";
        postscreen_blacklist_action = "drop";
        postscreen_greet_action = "ignore";

        postscreen_bare_newline_enable = "yes";
        postscreen_bare_newline_action = "enforce";
        postscreen_dnsbl_action = "enforce";
        postscreen_dnsbl_threshold = "2";
        postscreen_dnsbl_whitelist_threshold = "-2";
        postscreen_dnsbl_sites = "zen.spamhaus.org*2 dnsbl.dronebl.org*2 bl.spamcop.net*1";
        postscreen_cache_map = "btree:/var/lib/postfix/data/postscreen_cache";

        smtpd_helo_required = "yes";
        smtpd_helo_restrictions = lib.strings.concatMapStrings (x: x + ",") [
          "permit_mynetworks"
          "reject_non_fqdn_helo_hostname"
          "reject_invalid_helo_hostname"
          "reject_rhsbl_helo dbl.spamhaus.org"
          "permit"
        ];
        smtpd_sender_restrictions = lib.strings.concatMapStrings (x: x + ",") [
          "permit_mynetworks"
          "permit_sasl_authenticated"
          "reject_non_fqdn_sender"
          "reject_unknown_sender_domain"
          "reject_rhsbl_sender dbl.spamhaus.org"
          "permit"
        ];
        smtpd_recipient_restrictions = lib.strings.concatMapStrings (x: x + ",") [
          "reject_invalid_hostname"
          "reject_unknown_recipient_domain"
          "reject_unauth_pipelining"
          "reject_multi_recipient_bounce"
          "permit_mynetworks"
          "reject_non_fqdn_recipient"
          "reject_unauth_destination"
          "reject_rbl_client dnsbl.dronebl.org"
          "reject_rbl_client zen.spamhaus.org"
          "reject_rbl_client bl.spamcop.net"
          "reject_rbl_client b.barracudacentral.org"
          "reject_rbl_client dnsbl-1.uceprotect.net"
          "permit"
        ];
      };

      master = {
        # smtp_inet is the NixOS key for the inbound smtp inet listener (outputs as "smtp" in master.cf).
        # Overriding it here replaces the default smtpd command with postscreen.
        # The default smtp = {} unix transport key is left intact for outbound delivery.
        smtp_inet = {
          name = "smtp";
          type = "inet";
          private = false;
          maxproc = 1;
          command = lib.mkForce "postscreen -v";

        };
        smtpd = {
          type = "pass";
          maxproc = 0;
          command = "smtpd";
        };
        dnsblog = {
          type = "unix";
          maxproc = 0;
          command = "dnsblog";
        };
        tlsproxy = {
          type = "unix";
          maxproc = 0;
          command = "tlsproxy";
        };
      };
    };

  };
}
