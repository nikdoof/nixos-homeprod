{
  description = "nikdoof's home production NixOS configuration";

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
        svc-01 = nixpkgs.lib.nixosSystem {
          modules = [
            ./hosts/svc-01/configuration.nix
            agenix.nixosModules.default
          ];
        };
        svc-02 = nixpkgs.lib.nixosSystem {
          modules = [
            ./hosts/svc-02/configuration.nix
            agenix.nixosModules.default
          ];
        };
      };
    };
}
