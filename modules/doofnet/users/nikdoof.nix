{
  pkgs,
  ...
}:

{
  security.sudo.extraRules = [
    {
      users = [ "nikdoof" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  users = {
    defaultUserShell = pkgs.zsh;
    users.nikdoof = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
      ];
      hashedPassword = "$y$j9T$aDRuJzalAuPqielQz24Rx0$Y/fAk5cnSNrADjDoqbtEC58QWzR0QrKOODUJ56ZSGP/";
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHWO2qwHaPaQs46na4Aa6gMkw5QqRHUMGQphtgAcDJOw"
      ];
    };
  };
}
