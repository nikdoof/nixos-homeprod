# Foundry Virtual Tabletop - Node.js edition
#
# FoundryVTT is a paid application. The zip must be downloaded manually from
# https://foundryvtt.com/ (select "Node.js" in the OS dropdown).
#
# To provision the zip into the Nix store:
#
#   nix-store --add-fixed sha256 --name foundryvtt.zip path/to/FoundryVTT-X.X.X.zip
#
# The build will also tell you this if the file is missing.

{
  lib,
  stdenvNoCC,
  requireFile,
  unzip,
}:

let
  zipName = "foundryvtt.zip";
  zipHash = "sha256-glPN+Zc6/mHO5Qg/nQDH5Hjbv3vS7B6R5vCnXUEdzRY=";
  version = "14-366";
in
stdenvNoCC.mkDerivation {
  pname = "foundryvtt";
  version = "14.366"; # update to match your version

  src = requireFile {
    name = zipName;
    sha256 = zipHash;
    message = ''
      FoundryVTT is a paid application. To build, download the Node.js zip from
      https://foundryvtt.com/ and add it to the Nix store:

        nix-store --add-fixed sha256 --name ${zipName} /path/to/FoundryVTT-${version}.zip
    '';
  };

  sourceRoot = ".";

  buildInputs = [ unzip ];

  # The zip extracts the app at the root — no subdirectory.
  unpackPhase = ''
    unzip $src
  '';

  installPhase = ''
    mkdir -p $out
    mv * $out/
  '';

  meta = with lib; {
    description = "Foundry Virtual Tabletop - Node.js server";
    homepage = "https://foundryvtt.com";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
