{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./users.nix
  ];

  nix.settings.max-jobs = lib.mkDefault 1;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.auto-optimise-store = true;

  users.motdFile = builtins.path {
    path = ../files/motd;
    name = "motd";
  };

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";
  console = {
    #packages = [ pkgs.spleen pkgs.tamsyn ];
    #font = "spleen-12x24";
    useXkbConfig = true; # use xkb.options in tty.
    colors = [
      "292d3e"
      "ff5370"
      "c4e88d"
      "ffcb6b"
      "82aaff"
      "c692e9"
      "8addff"
      "b5bbd6"
      "676e95"
      "ff5370"
      "c3e88d"
      "ffcb6b"
      "82a9fe"
      "c792e9"
      "8addff"
      "88ddff"
      "ffffff"
    ];
  };

  programs = {
    git.enable = true;
    zsh = {
      enable = true;
      shellAliases = {
        # NixOS
        nrs = "sudo nixos-rebuild switch --refresh --flake github:nikdoof/nixos-homeprod#$(hostname)";
      };
    };
    ssh.startAgent = true;
  };

  environment.variables = {
    EDITOR = "nano";
    VISUAL = "nano";
  };

  environment.systemPackages = with pkgs; [
    gnupg
  ];

  services = {
    openssh = {
      enable = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];
}
