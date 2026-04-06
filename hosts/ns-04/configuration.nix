{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];
  ec2.efi = true;

  networking.hostName = "ns-04";
  networking.domain = "doofnet.uk";
  networking.search = [ "doofnet.uk" ];

  doofnet.bind = {
    enable = true;
    mode = "secondary";
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
