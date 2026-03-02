{
  nixpkgs,
  inputs,
  mkMAC,
}:
name:
{
  system ? "x86_64-linux",
  extraModules ? [ ],
}:
nixpkgs.lib.nixosSystem {
  inherit system;

  specialArgs = {
    inherit inputs mkMAC;
  };

  modules = [
    ../hosts/${name}/configuration.nix
    inputs.agenix.nixosModules.default
  ]
  ++ extraModules;
}
