# modules/doofnet/system.nix
#
# Host classification helpers for doofnet modules.
#
# Usage in a module:
#
#   { config, ... }:
#   let system = import ./system.nix config; in
#   {
#     services.fstrim.enable = system.isPhysical;
#   }
#
# Or destructure what you need:
#
#   let inherit (import ./system.nix config) isPhysical isKVM; in
#
# Detection signals:
#   isMicroVM   — doofnet microvm.nix guest (QEMU/KVM via microvm.nix)
#   isEC2       — Amazon EC2 instance (amazon-image.nix + ec2.efi = true)
#   isKVM       — generic QEMU/KVM guest; requires importing
#                 nixos/modules/profiles/qemu-guest.nix or setting
#                 services.qemuGuest.enable = true explicitly
#   isContainer — systemd-nspawn / NixOS container (boot.isContainer)
#   isPhysical  — none of the above

config:
let
  isMicroVM = (config.doofnet ? microvm) && config.doofnet.microvm.enable;
  isEC2 = (config ? ec2) && config.ec2.efi;
  isKVM = config.services.qemuGuest.enable;
  inherit (config.boot) isContainer;
in
{
  inherit
    isMicroVM
    isEC2
    isKVM
    isContainer
    ;

  # True when running in any virtualised or containerised environment.
  isVirtual = isMicroVM || isEC2 || isKVM || isContainer;

  # True when running on physical hardware.
  isPhysical = !isMicroVM && !isEC2 && !isKVM && !isContainer;
}
