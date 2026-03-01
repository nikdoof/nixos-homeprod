{ inputs, ... }:
{
  microvm.vms.ns-02 = {
    flake = inputs.self;
    restartIfChanged = true;
  };
  microvm.vms.ns-01 = {
    flake = inputs.self;
    restartIfChanged = true;
  };
}
