{
  description = "Homeprod";

  inputs = {
    # NixOS official package source, using the nixos-25.11 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    agenix.url = "github:ryantm/agenix";
  };

  outputs =
    {
      self,
      nixpkgs,
      agenix,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        default = nixpkgs.lib.nixosSystem {
          modules = [
            agenix.nixosModules.default
          ];
        };
        svc-01 = default {
          modules = [
            ./hosts/svc-01/configuration.nix
          ];
        };
      };
    };
}
