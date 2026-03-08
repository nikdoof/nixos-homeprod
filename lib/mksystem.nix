{
  self,
  nixpkgs,
  inputs,
}:
let
  mkMAC = import ./mkmac.nix { };
in
name:
{
  system ? "x86_64-linux",
  extraModules ? [ ],
}:
nixpkgs.lib.nixosSystem {
  inherit system;

  specialArgs = {
    inherit self inputs mkMAC;
  };

  modules = [
    ../hosts/${name}/configuration.nix
    inputs.agenix.nixosModules.default
  ]
  ++ extraModules;
}
