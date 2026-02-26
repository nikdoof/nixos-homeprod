{ lib, ... }:
{

  services.atftpd = {
    enable = true;
    root = "/srv/data/tftp";
  };

  networking.firewall.allowedUDPPorts = [ 69 ];

  system.activationScripts.rs-tftpd = lib.stringAfter [ "var" ] ''
    if ! [ -f /srv/data/tftp ]; then mkdir -p "/srv/data/tftp"; fi
    chmod u+rwX,g+rX,o+rX "/srv/data/tftp"
  '';
}
