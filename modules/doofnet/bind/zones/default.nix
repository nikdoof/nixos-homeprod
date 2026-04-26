{ dns }:
let
  zlib = import ./lib.nix;

  # Files in this directory that are not zones (loader + helper library).
  nonZoneFiles = [
    "default.nix"
    "lib.nix"
  ];

  zoneFiles = builtins.filter (
    name: !(builtins.elem name nonZoneFiles) && (builtins.match ".*\\.nix" name) != null
  ) (builtins.attrNames (builtins.readDir ./.));

  # Convert filename to zone name by removing the .nix extension
  filenameToZoneName = filename: builtins.substring 0 ((builtins.stringLength filename) - 4) filename;

  importZone =
    file:
    let
      zoneName = filenameToZoneName file;
      zoneConfig = import (./. + "/${file}") {
        inherit dns zlib;
      };
    in
    {
      name = zoneName;
      value = zoneConfig;
    };

  zones = builtins.listToAttrs (map importZone zoneFiles);
in
zones
