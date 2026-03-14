{
  inputs,
  lib,
  config,
  ...
}:
{
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
}
