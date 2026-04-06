{
  lib,
  config,
  pkgs,
  self,
  ...
}:
let
  inherit (import ./system.nix config) isPhysical;

  flakeRevision = self.rev or "dirty";

  promInternalTarget = "http://svc-02.int.doofnet.uk:9090";
  # promExternalTarget = "https://prometheus.doofnet.uk";

  lokiInternalTarget = "https://loki.svc.doofnet.uk";
  # lokiExternalTarget = "https://loki.doofnet.uk";

  alloyConfig = pkgs.writeText "alloy-config.alloy" ''
    // Collect system metrics (node_exporter replacement)
    prometheus.exporter.unix "default" {
      enable_collectors = ["logind", "processes", "systemd"]

      textfile {
        directory = "/var/lib/prometheus/node-exporter"
      }
    }

    prometheus.scrape "unix" {
      targets    = prometheus.exporter.unix.default.targets
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "node_exporter"
    }

    prometheus.remote_write "default" {
      endpoint {
        url = "${promInternalTarget}/api/v1/write"

        write_relabel_config {
          target_label = "host"
          replacement  = "${config.networking.hostName}"
        }
      }
    }

    // Scrape Alloy's own internal metrics
    prometheus.scrape "alloy" {
      targets    = [{"__address__" = "localhost:12345"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "alloy"
    }

    // Relabel systemd unit name from journal metadata
    loki.relabel "journal" {
      forward_to = []

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }
    }

    // Journal pipeline - relabels specific log streams before writing to Loki.
    // stage.match only fires when lines are present; harmless on hosts that
    // never produce the matched pattern.
    loki.process "journal_pipeline" {
      // nftables kernel drop messages have no systemd unit; reassign their job
      // label so they can be queried as {job="firewall"} separately in Grafana.
      stage.match {
        selector = `{job="systemd-journal"} |= "nft-forward-drop:"`

        stage.static_labels {
          values = {job = "firewall"}
        }
      }

      forward_to = [loki.write.default.receiver]
    }

    // Collect systemd journal logs
    loki.source.journal "default" {
      max_age       = "12h"
      labels        = {job = "systemd-journal", host = "${config.networking.hostName}"}
      forward_to    = [loki.process.journal_pipeline.receiver]
      relabel_rules = loki.relabel.journal.rules
    }

    loki.write "default" {
      endpoint {
        url = "${lokiInternalTarget}/loki/api/v1/push"
      }
    }
  '';
in
{
  options.doofnet.server = lib.mkEnableOption "Server Mode" // {
    default = true;
  };

  config = lib.mkIf config.doofnet.server (
    lib.mkMerge [
      {
        # Use dbus broker for Alloy access
        services.dbus.implementation = "broker";

        # World-writable so the DynamicUser alloy service (arbitrary UID) and any
        # custom textfile-writing scripts can both write here.
        systemd.tmpfiles.rules = [ "d /var/lib/prometheus/node-exporter/ 0777 root root" ];

        # Write the flake revision as a textfile metric on every activation so
        # Prometheus can detect hosts running a stale configuration.
        # Value is the Unix timestamp of activation so PromQL can deduplicate
        # by selecting max(value) per host when a revision transition is in flight.
        system.activationScripts.nixos-flake-revision-prom.text = ''
          mkdir -p /var/lib/prometheus/node-exporter
          printf '# HELP nixos_flake_revision Unix timestamp of the last NixOS flake activation\n# TYPE nixos_flake_revision gauge\nnixos_flake_revision{revision="${flakeRevision}"} %s\n' \
            "$(date +%s)" \
            > /var/lib/prometheus/node-exporter/nixos-flake-revision.prom
        '';

        environment.etc."alloy/conf.d/00-base.alloy".source = alloyConfig;

        services.alloy = {
          enable = true;
          configPath = "/etc/alloy/conf.d";
        };

        # ReadWritePaths ensures the path is accessible through systemd's filesystem
        # isolation even though alloy runs as a DynamicUser.
        systemd.services.alloy.serviceConfig.ReadWritePaths = [ "/var/lib/prometheus/node-exporter" ];
      }
      # Borgmatic is only enabled on hosts that have source_directories configured.
      # Keeping secrets and service conditional avoids agenix decryption failures
      # on hosts (e.g. microvms) whose SSH keys are not in the secret recipients list.
      (lib.mkIf
        (
          config.services.borgmatic.settings != null
          && config.services.borgmatic.settings.source_directories != [ ]
        )
        {
          age.secrets = {
            borgmaticEncryptionKey.file = ../../secrets/borgmaticEncryptionKey.age;
            borgmaticSSHKey.file = ../../secrets/borgmaticSSHKey.age;
          };

          programs.ssh.knownHosts."hetzner-storagebox" = {
            hostNames = [ "[u453638.your-storagebox.de]:23" ];
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
          };

          systemd.services.borgmatic.serviceConfig.ExecStartPre = [
            "-${pkgs.borgmatic}/bin/borgmatic init --encryption repokey-blake2"
          ];

          services.borgmatic = {
            enable = true;
            configurations."hetzner" = {
              repositories = [
                {
                  label = "hetzner-sb1";
                  path = "ssh://u453638-sub3@u453638.your-storagebox.de:23/./${config.networking.hostName}.borg";
                }
              ];
              remote_path = "borg";
              exclude_if_present = [ ".nobackup" ];

              encryption_passcommand = "${pkgs.coreutils}/bin/cat ${config.age.secrets.borgmaticEncryptionKey.path}";
              ssh_command = "ssh -i ${config.age.secrets.borgmaticSSHKey.path}";

              keep_daily = 7;
              keep_weekly = 4;
              keep_monthly = 6;
              keep_yearly = 1;
            };
          };

          services.prometheus.exporters.borgmatic = {
            enable = true;
            port = 9996;
            listenAddress = "127.0.0.1";
          };

          environment.etc."alloy/conf.d/02-borgmatic.alloy".text = ''
            prometheus.scrape "borgmatic" {
              targets    = [{"__address__" = "localhost:9996"}]
              forward_to = [prometheus.remote_write.default.receiver]
              job_name   = "borgmatic"
            }
          '';
        }
      )

      # Hardware related services, skipped on virtual
      (lib.mkIf isPhysical {
        services.prometheus.exporters.smartctl = {
          enable = true;
          port = 9633;
          listenAddress = "127.0.0.1";
        };

        environment.etc."alloy/conf.d/02-smartctl.alloy".text = ''
          prometheus.scrape "smartctl" {
            targets    = [{"__address__" = "localhost:9633"}]
            forward_to = [prometheus.remote_write.default.receiver]
            job_name   = "smartctl"
          }
        '';

        services.lldpd = {
          enable = true;
        };
      })
    ]
  );
}
