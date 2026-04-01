_: {
  services.avahi = {
    enable = true;
    reflector = true;
    allowInterfaces = [
      "vlan-private"
      "vlan-lab"
      "vlan-ha"
    ];
    ipv4 = true;
    ipv6 = true;
    openFirewall = false;
  };
}
