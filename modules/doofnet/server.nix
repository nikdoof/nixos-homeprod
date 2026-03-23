{
  lib,
  config,
  pkgs,
  ...
}:
let
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
        url = "http://svc-02.int.doofnet.uk:9090/api/v1/write"
      }
    }

    // Relabel systemd unit name from journal metadata
    loki.relabel "journal" {
      forward_to = []

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }
    }

    // Collect systemd journal logs
    loki.source.journal "default" {
      max_age       = "12h"
      labels        = {job = "systemd-journal", host = "${config.networking.hostName}"}
      forward_to    = [loki.write.default.receiver]
      relabel_rules = loki.relabel.journal.rules
    }

    loki.write "default" {
      endpoint {
        url = "https://loki.svc.doofnet.uk/loki/api/v1/push"
      }
    }
  '';
in
{
  options.doofnet.server = lib.mkEnableOption "Server Mode";

  config = lib.mkIf config.doofnet.server (
    lib.mkMerge [
      {
        age.secrets = {
          borgmaticEncryptionKey.file = ../../secrets/borgmaticEncryptionKey.age;
          borgmaticSSHKey.file = ../../secrets/borgmaticSSHKey.age;
        };

        # Use dbus broker for Alloy access
        services.dbus.implementation = "broker";

        # World-writable so the DynamicUser alloy service (arbitrary UID) and any
        # custom textfile-writing scripts can both write here.
        systemd.tmpfiles.rules = [ "d /var/lib/prometheus/node-exporter/ 0777 root root" ];

        environment.etc."alloy/conf.d/00-base.alloy".source = alloyConfig;

        services.alloy = {
          enable = true;
          configPath = "/etc/alloy/conf.d";
        };

        # ReadWritePaths ensures the path is accessible through systemd's filesystem
        # isolation even though alloy runs as a DynamicUser.
        systemd.services.alloy.serviceConfig.ReadWritePaths = [ "/var/lib/prometheus/node-exporter" ];

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

      }
      (lib.mkIf
        (
          config.services.borgmatic.settings != null
          && config.services.borgmatic.settings.source_directories != [ ]
        )
        {
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
      # Configure smart monitoring if not a VM
      (lib.mkIf (!(config.doofnet ? microvm) || !config.doofnet.microvm.enable) {
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
      })
    ]
  );
}
