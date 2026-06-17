_: {
  services.rspamd = {
    enable = true;

    locals = {
      "greylisting.conf".text = "enabled = true;";
      "dmarc.conf".text = ''
        reporting_enabled = true;
        actions = "reject:reject;";
      '';
      "milter_headers.conf".text = ''
        use = ["x-spam-score", "x-spam-level", "authentication-results"];
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
      extraConfig = "milter = yes; timeout = 120s;";
    };
  };

  # Rspamd web UI access restricted to admin networks
  networking.firewall.interfaces."lo".allowedTCPPorts = [ 11334 ];
}
