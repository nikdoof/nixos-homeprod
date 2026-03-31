_: {
  # Avahi mDNS reflector — re-transmits mDNS traffic between private, lab,
  # and HA VLANs at the application level (not kernel FORWARD).
  # openFirewall is false because we manage nftables directly; the INPUT
  # rule for UDP 5353 is in firewall.nix.
  services.avahi = {
    enable = true;
    reflector = true;
    interfaces = [
      "vlan-private"
      "vlan-lab"
      "vlan-ha"
    ];
    ipv4 = true;
    ipv6 = true;
    openFirewall = false;
  };
}
