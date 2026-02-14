# Raspberry Pi Systems

## Requirements

* A system capable of emulating `aarch64-linux`
* Nix
* A `nixosConfiguration` that imports `"${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"` from Nixpkgs. (see [flake.nix](../flake.nix) and [ns1 host](../hosts/ns-01/))

## Pre-setup

* A build system is required (suggested a NixOS system) with configuration for emulation:

```nix
  # Allows for cross compling for Pis
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  nix.settings.extra-platforms = [
    "aarch64-linux"
    "arm-linux"
  ];
```

## Building

Run `nix-build` targetting the configuration, in this case, the Flake `nixosConfigurations` `sdImage`

```shell-common
nikdoof@svc-02:~/ > nix build --refresh github:nikdoof/nixos-homeprod#nixosConfigurations.ns-01.config.system.build.sdImage
nikdoof@svc-02:~/ > ls
result
nikdoof@svc-02:~/ > ls result
nix-support  sd-image
nikdoof@svc-02:~/ > ls result/sd-image
nixos-image-sd-card-25.11.20260207.23d72da-aarch64-linux.img.zst
nikdoof@svc-02:~/ >
```

This results in a standard `img` file that can be wrote to a SD card.
