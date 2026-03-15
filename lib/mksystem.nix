{
  self,
  nixpkgs,
  inputs,
}:
let
  lib = nixpkgs.lib.extend (_: _: { mkMAC = import ./mkmac.nix { }; });
in
name:
{
  system ? "x86_64-linux",
  extraModules ? [ ],
}:
nixpkgs.lib.nixosSystem {
  inherit system lib;

  specialArgs = {
    inherit self inputs;
  };

  modules = [
    ../hosts/${name}/configuration.nix
    inputs.agenix.nixosModules.default
    ../modules/doofnet
  ]
  ++ extraModules;
}
