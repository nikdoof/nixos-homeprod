{
  description = "nikdoof's home production NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-hardware = {
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
    globaltalk = {
      url = "github:nikdoof/globaltalk-scraper";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    aaisp-chaos = {
      url = "github:nikdoof/aaisp-chaos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;

      mkSystem = import ./lib/mksystem.nix {
        inherit
          self
          nixpkgs
          inputs
          ;
      };

      mkMicrovm =
        name: args:
        mkSystem name (
          args
          // {
            extraModules = (args.extraModules or [ ]) ++ [
              inputs.microvm.nixosModules.microvm
              ./modules/doofnet/microvm.nix
            ];
          }
        );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          jrouter = pkgs.callPackage ./packages/jrouter.nix { };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          deadnix = pkgs.runCommand "deadnix" { } ''
            ${pkgs.deadnix}/bin/deadnix --fail ${./.}
            touch $out
          '';
          statix = pkgs.runCommand "statix" { } ''
            cd ${./.} && ${pkgs.statix}/bin/statix check --config ${./statix.toml} .
            touch $out
          '';
          format = pkgs.runCommand "nixfmt-check" { } ''
            ${pkgs.nixfmt-rfc-style}/bin/nixfmt --check $(find ${./.} -name '*.nix' -not -path '*/\.*')
            touch $out
          '';
        }
      );

      nixosConfigurations = {
        # Physical Hosts
        gw = mkSystem "gw" { };
        hyp-01 = mkSystem "hyp-01" { extraModules = [ inputs.microvm.nixosModules.host ]; };
        ns-01 = mkSystem "ns-01" { system = "aarch64-linux"; };
        svc-01 = mkSystem "svc-01" { };
        svc-02 = mkSystem "svc-02" { extraModules = [ inputs.aaisp-chaos.nixosModules.default ]; };

        # VMs
        afp-01 = mkMicrovm "afp-01" { extraModules = [ inputs.globaltalk.nixosModules.default ]; };
        grf-01 = mkMicrovm "grf-01" { };
        hs-01 = mkMicrovm "hs-01" { };
        mx-01 = mkMicrovm "mx-01" { };
        web-01 = mkMicrovm "web-01" { };
        ns-02 = mkMicrovm "ns-02" { };

        # AWS
        ns-03 = mkSystem "ns-03" { system = "aarch64-linux"; };
        ns-04 = mkSystem "ns-04" { system = "aarch64-linux"; };

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
              pkgs.deadnix
              pkgs.nixfmt-rfc-style
              pkgs.statix
            ];
          };
      });
    };
}
