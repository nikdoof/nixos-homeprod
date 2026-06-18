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
        sign_condition = "return true;";
        selector = "${selector}";
        path = "/persist/opendkim/keys/${selector}.private";
      '';
      "greylisting.conf".text = "enabled = true;";
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
        timeout = 120s;
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
