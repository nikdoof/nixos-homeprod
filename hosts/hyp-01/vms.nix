{
  inputs,
  lib,
  config,
  ...
}:
{
  microvm.vms.ns-02 = {
    flake = inputs.self;
    restartIfChanged = true;
  };
  microvm.vms.hs-01 = {
    flake = inputs.self;
    restartIfChanged = true;
  };
  microvm.vms.web-01 = {
    flake = inputs.self;
    restartIfChanged = true;
  };
  microvm.vms.mx-01 = {
    flake = inputs.self;
    restartIfChanged = true;
  };

  # Make the persistent folders for VMs
  systemd.tmpfiles.rules = lib.concatMap (vm: [
    "d /srv/data/persist/microvms/${vm} 0755 root root -"
  ]) (builtins.attrNames config.microvm.vms);
}
