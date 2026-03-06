{ inputs, ... }:
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
}
