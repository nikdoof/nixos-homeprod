{
  description = "Homeprod";

  inputs = {
    # NixOS official package source, using the nixos-25.11 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    {

      nixosConfigurations.svc-01 = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/svc-01/configuration.nix
        ];
      };
    };
}
