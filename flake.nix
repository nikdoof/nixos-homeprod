{
  description = "nikdoof's home production NixOS configuration";

  inputs = {
    # Tracking nixos-25.11 (upcoming release branch) intentionally.
    # Switch to nixos-24.11 for a stable channel.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-hardware = {
      # nixos-hardware does not have release branches; we pin to a specific
      # commit via the lock file. Removing /master lets `nix flake update`
      # track HEAD without silently floating on the branch ref.
      url = "github:NixOS/nixos-hardware";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    microvm = {
      url = "github:microvm-nix/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dns = {
      url = "github:nix-community/dns.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deadnix = {
      url = "github:astro/deadnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    globaltalk = {
      url = "github:nikdoof/globaltalk-scraper";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
        inherit nixpkgs inputs mkMAC;
      };
      mkMAC = import ./lib/mkmac.nix {
        inherit inputs;
      };
    in
    {
      nixosConfigurations = {
        afp-01 = mkSystem "afp-01" { extraModules = [ inputs.globaltalk.nixosModules.default ]; };
        svc-01 = mkSystem "svc-01" { };
        svc-02 = mkSystem "svc-02" { };
        mx-01 = mkSystem "mx-01" { };
        hs-01 = mkSystem "hs-01" { };
        web-01 = mkSystem "web-01" { };
        hyp-01 = mkSystem "hyp-01" { extraModules = [ inputs.microvm.nixosModules.host ]; };

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
              inputs.deadnix.packages.${system}.deadnix
              pkgs.statix
            ];
          };
      });
    };
}
