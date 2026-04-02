{
  lib,
  config,
  ...
}:
{
  options.doofnet.fail2ban = {
    enable = lib.mkEnableOption "fail2ban intrusion prevention";
    jails = {
      dovecot = lib.mkEnableOption "Dovecot authentication failure jail";
    };
  };

  config = lib.mkIf config.doofnet.fail2ban.enable (
    lib.mkMerge [
      {
        services.fail2ban = {
          enable = true;
          maxretry = 5;
          bantime = "10m";

          bantime-increment = {
            enable = true;
            # Double ban duration on each repeat offence, up to 7 days
            multipliers = "1 2 4 8 16 32 64";
            maxtime = "168h";
            # Count bans across all jails for the same IP
            overalljails = true;
          };

          ignoreIP = [
            "127.0.0.0/8"
            "::1"
            "10.0.0.0/8"
            "2001:8b0:bd9::/48"
          ];

          jails.sshd.settings = {
            enabled = true;
            backend = "systemd";
          };
        };
      }

      (lib.mkIf config.doofnet.fail2ban.jails.dovecot {
        services.fail2ban.jails.dovecot.settings = {
          enabled = true;
          filter = "dovecot";
          backend = "systemd";
        };
      })
    ]
  );
}
