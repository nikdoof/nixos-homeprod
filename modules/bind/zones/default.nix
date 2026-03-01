{ dns }:
let
  dns_masters = [ "10.101.1.2" ];
  dns_slaves = [ "10.101.1.3" ];

  # Get all .nix files in the current directory except default.nix
  zoneFiles = builtins.filter (
    name: name != "default.nix" && (builtins.match ".*\\.nix" name) != null
  ) (builtins.attrNames (builtins.readDir ./.));

  # Convert filename to zone name by removing the .nix extension
  filenameToZoneName = filename: builtins.substring 0 ((builtins.stringLength filename) - 4) filename;

  # Import each zone file with the required arguments
  importZone =
    file:
    let
      zoneName = filenameToZoneName file;
      zoneConfig = import (./. + "/${file}") {
        inherit dns dns_masters dns_slaves;
      };
    in
    {
      name = zoneName;
      value = zoneConfig;
    };

  # Create an attribute set of all zones
  zones = builtins.listToAttrs (map importZone zoneFiles);
in
zones
