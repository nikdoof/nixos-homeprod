{ inputs, ... }:
{
  microvm.vms.ns-02 = {
    flake = inputs.self;
    restartIfChanged = true;
  };
}
