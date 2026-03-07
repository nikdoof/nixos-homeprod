{
  lib,
  buildGoModule,
  libpcap,
  ...
}:
buildGoModule rec {
  pname = "jrouter";
  version = "0.0.21";

  src = fetchTarball {
    url = "https://gitea.drjosh.dev/josh/jrouter/archive/v${version}.tar.gz";
    sha256 = "11z89l5h9qi3rk6fhfww6w8ahmga2x7d9kn9rwcr5v4g6sbc4g6i";
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
