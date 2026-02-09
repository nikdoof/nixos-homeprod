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
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
    in
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
        talos = nixpkgs.lib.nixosSystem {
          modules = [
            ./hosts/talos/configuration.nix
          ];
        };
      };

      devShells = forAllSystems (system: {
        default =
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          pkgs.mkShell {
            packages = [
              agenix.packages.${system}.agenix
            ];
          };
      });
    };
}
