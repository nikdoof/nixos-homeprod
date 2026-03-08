{
  pkgs,
  config,
  ...
}:

{
  # NOTE: the nikdoofHashedPassword.age secret must be created before deploying:
  #   echo '<hashed-password>' | agenix -e secrets/nikdoofHashedPassword.age
  # Generate a hash with: mkpasswd -m yescrypt
  age.secrets.nikdoofHashedPassword = {
    file = ../../../secrets/nikdoofHashedPassword.age;
  };

  users = {
    defaultUserShell = pkgs.zsh;
    users.nikdoof = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
      ];
      hashedPasswordFile = config.age.secrets.nikdoofHashedPassword.path;
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHWO2qwHaPaQs46na4Aa6gMkw5QqRHUMGQphtgAcDJOw"
      ];
    };
  };
}
