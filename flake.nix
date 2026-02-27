{
  description = "nikdoof's home production NixOS configuration";

  inputs = {
    # NixOS official package source, using the nixos-25.11 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;

      mkSystem = import ./lib/mksystem.nix {
        inherit nixpkgs inputs;
      };
    in
    {
      nixosConfigurations = {
        svc-01 = mkSystem "svc-01" { };
        svc-02 = mkSystem "svc-02" { };
        mx-01 = mkSystem "mx-01" { };
        hyp-01 = mkSystem "hyp-01" {
          extraModules = [ inputs.microvm.nixosModules.host ];
        };

        # Nameservers
        ns-01 = mkSystem "ns-01" {
          system = "aarch64-linux";
          extraModules = [
            {
              nix.settings = {
                substituters = [
                  "https://nix-community.cachix.org"
                ];
                trusted-public-keys = [
                  "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                ];
              };
            }
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          ];
        };
        ns-02 = mkSystem "ns-02" { };

        # Mini P8 Laptop
        talos = mkSystem "talos" { };
      };

      devShells = forAllSystems (system: {
        default =
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          pkgs.mkShell {
            packages = [
              inputs.agenix.packages.${system}.agenix
            ];
          };
      });
    };
}
