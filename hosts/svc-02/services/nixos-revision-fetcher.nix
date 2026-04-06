{ pkgs, ... }:
let
  fetcherScript = pkgs.writeShellScript "prom-collect-nixos-repo-revision" ''
    set -euo pipefail
    out=/var/lib/prometheus/node-exporter/nixos-flake-repo-revision.prom
    tmp=$out.tmp

    revision=$(
      ${pkgs.curl}/bin/curl -sf \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/nikdoof/nixos-homeprod/git/ref/heads/main" \
        | ${pkgs.jq}/bin/jq -r '.object.sha'
    )

    {
      printf '# HELP nixos_flake_repo_revision Current HEAD revision of the NixOS flake GitHub repository\n'
      printf '# TYPE nixos_flake_repo_revision gauge\n'
      printf 'nixos_flake_repo_revision{revision="%s"} 1\n' "$revision"
    } > "$tmp" && mv "$tmp" "$out"
  '';
in
{
  systemd.services.prom-collect-nixos-repo-revision = {
    description = "Prometheus textfile collector: NixOS flake repository HEAD revision";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = fetcherScript;
    };
  };

  systemd.timers.prom-collect-nixos-repo-revision = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "5m";
    };
  };
}
