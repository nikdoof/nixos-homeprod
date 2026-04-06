# Raspberry Pi

Steps to build and flash a NixOS SD card image for `aarch64-linux` hosts such as
[ns-01](dns.md).

## Requirements

- A build system capable of emulating `aarch64-linux` (a NixOS host is recommended)
- Nix
- A `nixosConfiguration` that imports `sd-image-aarch64.nix` from Nixpkgs (see
  [`flake.nix`](../flake.nix) and [`hosts/ns-01/`](../hosts/ns-01/))

## Build system configuration

Add the following to the build system's NixOS configuration to enable aarch64 emulation:

```nix
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
nix.settings.extra-platforms = [
  "aarch64-linux"
  "arm-linux"
];
```

## Building an SD card image

Run `nix build` targeting the `sdImage` output of the relevant flake configuration:

```console
nikdoof@svc-02:~/ > nix build --refresh github:nikdoof/nixos-homeprod#nixosConfigurations.ns-01.config.system.build.sdImage
nikdoof@svc-02:~/ > ls result/sd-image
nixos-image-sd-card-25.11.20260207.23d72da-aarch64-linux.img.zst
```

This produces a standard `.img.zst` compressed image that can be written to an SD card
with a tool such as `dd` or [Raspberry Pi Imager](https://www.raspberrypi.com/software/).
