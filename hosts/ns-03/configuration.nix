{ modulesPath, ... }:
let
  hostName = "ns-03";
  domainName = "doofnet.uk";
in
{
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];
  ec2.efi = true;

  networking.hostName = hostName;
  networking.domain = domainName;
  networking.search = [ domainName ];

  doofnet.server = true;

  doofnet.bind = {
    enable = true;
    mode = "secondary";
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
