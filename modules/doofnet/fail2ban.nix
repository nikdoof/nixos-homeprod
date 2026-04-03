{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (import ./const.nix) allNetworks;

  # Exports per-jail ban counts and total failure counts from fail2ban to the
  # Prometheus textfile directory.  Requires root to call fail2ban-client.
  fail2banCollector = pkgs.writeShellScript "prom-collect-fail2ban" ''
    set -euo pipefail
    out=/var/lib/prometheus/node-exporter/fail2ban.prom
    tmp=$out.tmp

    {
      printf '# HELP fail2ban_banned_ips Current number of banned IPs per jail\n'
      printf '# TYPE fail2ban_banned_ips gauge\n'
      printf '# HELP fail2ban_failed_total Total failed attempts per jail (since service start)\n'
      printf '# TYPE fail2ban_failed_total counter\n'

      ${pkgs.fail2ban}/bin/fail2ban-client status 2>/dev/null \
        | ${pkgs.gnused}/bin/sed -n 's/.*Jail list:\s*//p' \
        | tr ',' '\n' \
        | tr -d ' \t' \
        | while IFS= read -r jail; do
            [ -z "$jail" ] && continue
            status=$(${pkgs.fail2ban}/bin/fail2ban-client status "$jail" 2>/dev/null) || continue
            banned=$(printf '%s' "$status" | ${pkgs.gnugrep}/bin/grep 'Currently banned:' | ${pkgs.gawk}/bin/awk '{print $NF}')
            failed=$(printf '%s' "$status" | ${pkgs.gnugrep}/bin/grep 'Total failed:'     | ${pkgs.gawk}/bin/awk '{print $NF}')
            printf 'fail2ban_banned_ips{jail="%s"} %s\n'   "$jail" "''${banned:-0}"
            printf 'fail2ban_failed_total{jail="%s"} %s\n' "$jail" "''${failed:-0}"
          done
    } > "$tmp" && mv "$tmp" "$out"
  '';
in
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
          ]
          ++ allNetworks;

          jails.sshd.settings = {
            enabled = true;
            backend = "systemd";
          };
        };
      }
      (lib.mkIf config.doofnet.server {
        # fail2ban exporter — runs every 60 s, writes fail2ban.prom
        systemd.services.prom-collect-fail2ban = {
          description = "Prometheus textfile collector: fail2ban jail stats";
          after = [ "fail2ban.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = fail2banCollector;
          };
        };
        systemd.timers.prom-collect-fail2ban = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "30s";
            OnUnitActiveSec = "60s";
          };
        };
      })
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
