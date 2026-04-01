{
  inputs,
  lib,
  config,
  ...
}:
let
  # Collect the CID for each declared VM by reading the guest's evaluated config
  # via inputs.self. This gives us host-side visibility across all guests so we
  # can assert uniqueness at evaluation time (i.e. during nix flake check).
  vmCIDs = lib.mapAttrsToList (
    name: _:
    let
      cid = inputs.self.nixosConfigurations.${name}.config.doofnet.microvm.cid;
    in
    {
      inherit name cid;
    }
  ) config.microvm.vms;

  # Group VMs by CID value - any group with more than one entry is a duplicate.
  cidGroups = lib.groupBy (vm: toString vm.cid) vmCIDs;
  duplicates = lib.filterAttrs (_: vms: builtins.length vms > 1) cidGroups;

  # Build a human-readable description of each conflicting CID.
  duplicateMsg = lib.concatStringsSep ", " (
    lib.mapAttrsToList (
      cid: vms: "CID ${cid} used by ${lib.concatMapStringsSep " and " (vm: vm.name) vms}"
    ) duplicates
  );
in
{
  assertions = [
    {
      assertion = duplicates == { };
      message = "Duplicate microVM CIDs on hyp-01: ${duplicateMsg}";
    }
  ];

  microvm.vms = {
    afp-01 = {
      flake = inputs.self;
      restartIfChanged = true;
    };
    ns-02 = {
      flake = inputs.self;
      restartIfChanged = true;
    };
    hs-01 = {
      flake = inputs.self;
      restartIfChanged = true;
    };
    web-01 = {
      flake = inputs.self;
      restartIfChanged = true;
    };
    mx-01 = {
      flake = inputs.self;
      restartIfChanged = true;
    };
    grf-01 = {
      flake = inputs.self;
      restartIfChanged = true;
    };
  };

  # Make the persistent folders for VMs
  systemd.tmpfiles.rules = lib.concatMap (vm: [
    "d /srv/data/persist/microvms/${vm} 0755 root root -"
  ]) (builtins.attrNames config.microvm.vms);

  # Backup persistent folders
  services.borgmatic.settings.source_directories = [ "/srv/data/persist/microvms" ];
}
