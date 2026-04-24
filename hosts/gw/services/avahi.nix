_: {
  services.avahi = {
    enable = true;
    reflector = true;
    allowInterfaces = [
      "vlan-private"
      "vlan-lab"
      # vlan-ha intentionally omitted: the HA VM is dual-homed onto
      # vlan-ha directly and will discover IoT devices on its own
      # eth1, so reflection is unnecessary. Including it caused mDNS
      # hostname-conflict loops (HAOS sees its own private-side
      # announcement reflected back onto vlan-ha and renumbers).
    ];
    ipv4 = true;
    ipv6 = true;
    openFirewall = false;
  };
}
