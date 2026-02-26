{ lib, pkgs, ... }:
{

  systemd.services.rs-tftpd = {
    description = "tftp server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.rs-tftpd}/bin/tftpd -r -d /srv/data/tftp";
      DynamicUser = true;
    };
  };

  networking.firewall.allowedUDPPorts = [ 69 ];

  system.activationScripts.rs-tftpd = lib.stringAfter [ "var" ] ''
    if ! [ -f /srv/data/tftp ]; then mkdir -p "/srv/data/tftp"; fi
    chmod u+rwX,g+rX,o+rX "/srv/data/tftp"
  '';
}
