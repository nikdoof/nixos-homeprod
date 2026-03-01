{ ... }:
{
  imports = [
    ./default.nix
  ];

  doofnet.bind = {
    enable = true;
    mode = "slave";
  };
}
