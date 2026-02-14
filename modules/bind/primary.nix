{ ... }:
{

  imports = [
    ./default.nix
  ];
  
  services.bind.zones = {
    "rpz"
  }
}
