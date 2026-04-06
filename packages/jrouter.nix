{
  lib,
  buildGoModule,
  fetchzip,
  libpcap,
}:
buildGoModule rec {
  pname = "jrouter";
  version = "0.0.21";

  src = fetchzip {
    url = "https://git.doofnet.uk/nikdoof-stars/jrouter/archive/v${version}.tar.gz";
    hash = "sha256-0TzCljaP7JIZz8nO1E4X6lWoEDecO+jMzCPiBAtN6Ic=";
  };

  buildInputs = [ libpcap ];

  vendorHash = "sha256-9htMWedvYFq1ZDSPblx/FykQYpf29bM1FVRvR3mU+5Y=";
  doCheck = false;

  meta = with lib; {
    description = "Home-grown alternative implementation of Apple Internet Router 3.0";
    homepage = "https://gitea.drjosh.dev/josh/jrouter/";
    license = licenses.apsl20;
    platforms = platforms.unix;
  };
}
