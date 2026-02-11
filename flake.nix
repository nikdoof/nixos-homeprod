{
  description = "nikdoof's home production NixOS configuration";

  inputs = {
    # NixOS official package source, using the nixos-25.11 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    agenix.url = "github:ryantm/agenix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs =
    {
      self,
      nixpkgs,
      agenix,
      nixos-hardware,
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
            nixos-hardware.nixosModules.common-cpu-intel
            nixos-hardware.nixosModules.common-pc-laptop
            nixos-hardware.nixosModules.common-hidpi
            nixos-hardware.nixosModules.common-pc-laptop-ssd
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
