{ inputs, ... }:
{
  microvm.vms.ns-02 = {
    flake = inputs.self;
    updateFlake = "git+https://github.com/nikdoof/nixos-homeprod";
    restartIfChanged = true;
  };
}
