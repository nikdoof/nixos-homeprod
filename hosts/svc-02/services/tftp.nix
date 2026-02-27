{
  pkgs,
  ...
}:
let
  tftp_data = pkgs.stdenv.mkDerivation {
    name = "tftp_data";
    src = ./files/tftp;
    phases = [
      "unpackPhase"
      "installPhase"
    ];
    installPhase = ''
      mkdir -p $out
      cp -r $src/* $out
    '';
  };
in
{

  services.atftpd = {
    enable = true;
    root = "${tftp_data}";
  };

  networking.firewall.allowedUDPPorts = [ 69 ];
}
