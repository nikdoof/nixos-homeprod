{
  lib,
  buildGoModule,
  fetchzip,
  libpcap,
}:
buildGoModule rec {
  pname = "jrouter";
  version = "0.0.23";

  src = fetchzip {
    url = "https://git.doofnet.uk/nikdoof-stars/jrouter/archive/v${version}.tar.gz";
    hash = "sha256-E752m9GKB9iAVYUXu9gMO9S/zjjyIVxCkPSPJhkNslU=";
  };

  buildInputs = [ libpcap ];

  vendorHash = "sha256-68DL2TyUxGGw8H9gzhFjgngyjUN4quH6FT5GvCMKiMA=";
  doCheck = false;

  meta = with lib; {
    description = "Home-grown alternative implementation of Apple Internet Router 3.0";
    homepage = "https://gitea.drjosh.dev/josh/jrouter/";
    license = licenses.apsl20;
    platforms = platforms.unix;
  };
}
