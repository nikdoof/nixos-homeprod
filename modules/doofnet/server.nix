{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
{
  options.doofnet.server = mkEnableOption "Server Mode";

  config = mkIf config.doofnet.server {
    age.secrets = {
      borgmaticEncryptionKey.file = ../../secrets/borgmaticEncryptionKey.age;
      borgmaticSSHKey.file = ../../secrets/borgmaticSSHKey.age;
    };

    services.prometheus.exporters.node = {
      enable = true;
      openFirewall = true;
      enabledCollectors = [
        "logind"
        "processes"
        "systemd"
      ];
      extraFlags = [
        "--collector.textfile.directory=/var/lib/prometheus/node-exporter/"
      ];
    };

    systemd.tmpfiles.rules = [ "d /var/lib/prometheus/node-exporter/ 0755 root root" ];

    # Allow node_exporter metrics port from Prometheus system
    networking.firewall = {
      extraCommands = ''
        iptables -A nixos-fw -p tcp -m tcp --dport ${toString config.services.prometheus.exporters.node.port} -s 10.101.0.0/16 -j nixos-fw-accept -m comment --comment "node_exporter"
        ip6tables -A nixos-fw -p tcp -m tcp --dport ${toString config.services.prometheus.exporters.node.port} -s fddd:d00f:dab0:101::/64 -j nixos-fw-accept -m comment --comment "node_exporter"
        ip6tables -A nixos-fw -p tcp -m tcp --dport ${toString config.services.prometheus.exporters.node.port} -s 2001:8b0:bd9:101::21/64 -j nixos-fw-accept -m comment --comment "node_exporter"
      '';
    };

    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 3031;
          grpc_listen_port = 0;
        };
        positions = {
          filename = "/var/lib/promtail/positions.yaml";
        };
        clients = [
          {
            url = "https://loki.svc.doofnet.uk/loki/api/v1/push";
          }
        ];
        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = config.networking.hostName;
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }
        ];
      };
      # extraFlags
    };

    services.borgmatic = {
      enable = true;
      configurations."hetzner" = {

        source_directories = [ "/srv/data" ];
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
  };
}
