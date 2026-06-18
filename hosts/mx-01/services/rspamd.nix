_:
let
  selector = "658553b1d7df5d1bc6bdb2176d87b585a0ad54ce";
in
{
  services.rspamd = {
    enable = true;

    locals = {
      "dkim_signing.conf".text = ''
        allow_hdrhash_md5 = false;
        sign_condition = "return not task:has_flag('empty_sender');";
        selector = "${selector}";
        path = "/persist/opendkim/keys/${selector}.private";
      '';
      "greylist.conf".text = "enabled = true;";
      "dmarc.conf".text = ''
        reporting_enabled = true;
        actions = "reject:reject;";
      '';
      "milter_headers.conf".text = ''
        use = ["x-spam-score", "x-spam-level", "authentication-results"];
      '';
      "redis.conf".text = ''
        servers = "127.0.0.1:6379";
      '';
      "settings.conf".text = ''
        authenticated {
          priority = high;
          authenticated = yes;
          apply {
            groups_disabled = ["rbl", "spf", "neural"];
            actions {
              reject = 100;
              "add header" = 20;
              greylist = 50;
            }
          }
        }
      '';
      "neural.conf".text = ''
        servers = "127.0.0.1:6379";
      '';
      "mx_check.conf".text = ''
        enabled = true;
      '';
      "ratelimit.conf".text = ''
        rates {
          authenticated_user {
            selector = "authenticated:user";
            bucket {
              burst = 200;
              rate = "100 / 1h";
            }
          }
        }
      '';
    };

    workers.controller = {
      type = "controller";
      bindSockets = [ "127.0.0.1:11334" ];
      count = 1;
    };

    workers.proxy = {
      type = "rspamd_proxy";
      bindSockets = [ "127.0.0.1:11332" ];
      count = 1;
      extraConfig = ''
        milter = yes;
        upstream "local" {
          default = yes;
          self_scan = yes;
        }
      '';
    };
  };

  # Rspamd web UI access restricted to admin networks
  networking.firewall.interfaces."lo".allowedTCPPorts = [ 11334 ];
}
