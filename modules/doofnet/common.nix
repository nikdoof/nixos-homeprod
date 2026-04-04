{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (import ./system.nix config) isMicroVM isPhysical;
in
{
  nix = lib.mkMerge [
    {
      settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
    }
    # Disable store maintenance on microvms - they share the host's /nix/store
    # via virtiofs and may remount it rw, so running GC or optimise from a guest
    # would corrupt the host store.
    (lib.mkIf (!isMicroVM) {
      settings.auto-optimise-store = true;
      gc = {
        automatic = true;
        dates = "daily";
        options = "--delete-older-than 7d";
      };
    })
  ];

  # Disable risky modules
  boot.blacklistedKernelModules = [
    "dccp" # CIS 3.4.1 — unused protocol with exploit history
    "sctp" # CIS 3.4.2 — unused protocol
    "rds" # CIS 3.4.3 — unused, had multiple CVEs
    "tipc" # CIS 3.4.4 — unused protocol
    "cramfs" # CIS 1.1.1.1 — legacy filesystem
    "freevxfs"
    "jffs2"
    "hfs"
    "hfsplus"
    "squashfs" # This may need removing
    "udf"
  ];

  networking.firewall = {
    logRefusedConnections = false;
  };

  users.motdFile = builtins.path {
    path = ./files/motd;
    name = "motd";
  };

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";
  console = {
    useXkbConfig = true; # use xkb.options in tty.

    # Nord theme colors for the console
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
    bat.enable = true;
    git.enable = true;
    zsh = {
      enable = true;
      shellAliases = {
        # NixOS
        nrs = "sudo nixos-rebuild switch --refresh --flake github:nikdoof/nixos-homeprod#$(hostname)";
        cat = "bat --paging=never";
        less = "bat";
        ls = "eza";
      };
    };
    ssh.startAgent = true;
  };

  environment.variables = {
    EDITOR = "nano";
    VISUAL = "nano";
  };

  # Ensure .zshrc exists for all normal users before their shell starts,
  # preventing the zsh-newuser-install wizard from running.
  systemd.tmpfiles.rules = lib.mapAttrsToList (
    name: user: "f ${user.home}/.zshrc 0644 ${name} users - -"
  ) (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);

  # Suppress the sudo first-use lecture
  security.sudo.extraConfig = "Defaults lecture=never";

  environment.systemPackages = with pkgs; [
    eza
    fzf
    gnupg
    jq
    lsof
    starship
    tcpdump
    yq
    pciutils
    dmidecode
    htop
  ];

  services = {
    openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = lib.mkForce "no";
        MaxAuthTries = 3;
        LoginGraceTime = 30;
        MaxSessions = 5;
        X11Forwarding = false;
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "certs@doofnet.uk";
  };

  services.fstrim.enable = lib.mkIf isPhysical true;
}
