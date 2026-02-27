{
  nixpkgs,
  inputs,
}:
name:
{
  system,
  extra_modules ? [ ],
}:
nixpkgs.lib.nixosSystem rec {
  inherit system;

  modules = [
    ../hosts/${name}/configuration.nix
    inputs.agenix.nixosModules.default
  ]
  ++ extra_modules;
}
