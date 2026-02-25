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

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    services.prometheus.exporters.node = {
      enable = true;
      openFirewall = true;
      enabledCollectors = [
        "logind"
        "processes"
        "systemd"
      ];
    };

    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 3031;
          grpc_listen_port = 0;
        };
        positions = {
          filename = "/tmp/positions.yaml";
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
