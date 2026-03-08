_: {
  nixpkgs.config.packageOverrides = pkgs: {
    jrouter = pkgs.callPackage ./jrouter.nix { };
  };
}
