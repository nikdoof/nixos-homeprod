{ pkgs, ... }:
{
  # Printing
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
    extraServiceFiles = {
      zebra = ./files/cups/AirPrint-Zebra_GK420d.service;
    };
  };

  services.printing = {
    enable = true;
    openFirewall = true;
    defaultShared = true;
    browsing = false;
    listenAddresses = [ "10.101.3.20:631" ];
    allowFrom = [ "all" ];

    drivers = [
      (pkgs.writeTextDir "share/cups/model/Zebra_GK420d.ppd" (
        builtins.readFile ./files/cups/Zebra_GK420d.ppd
      ))
    ];
  };

  systemd.timers."restart-printing-services" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      Unit = "restart-printing-services.service";
    };
  };

  systemd.services."restart-printing-services" = {
    script = ''
      ${pkgs.systemd}/bin/systemctl restart cups.service avahi-daemon.service
    '';
    serviceConfig.Type = "oneshot";
  };

  hardware.printers = {
    ensurePrinters = [
      {
        name = "Zebra_GK420d";
        description = "Zebra GK420d";
        location = "Games Room";
        deviceUri = "usb://Zebra%20Technologies/ZTC%20GK420d?serial=28J120703625";
        model = "Zebra_GK420d.ppd";

        ppdOptions = {
          PageSize = "6.00x4.00";
        };
      }
    ];
    ensureDefaultPrinter = "Zebra_GK420d";
  };
}
