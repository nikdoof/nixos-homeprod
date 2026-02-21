{
  config,
  pkgs,
  ...
}:

{
  age.secrets = {
    borgmaticEncryptionKey.file = ../secrets/borgmaticEncryptionKey.age;
    borgmaticSSHKey.file = ../secrets/borgmaticSSHKey.age;
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
}
