_: {
  # miniupnpd with nftables backend — required because networking.nftables.enable
  # is true and the default iptables build won't be available.
  # miniupnpd manages its own `miniupnpd` nftables table at runtime for port
  # mapping rules; it does not touch our `inet filter` or `ip nat` tables.
  #
  # The module has no `package` option so we overlay miniupnpd → miniupnpd-nftables.
  nixpkgs.overlays = [
    (_: prev: { miniupnpd = prev.miniupnpd-nftables; })
  ];

  services.miniupnpd = {
    enable = true;
    externalInterface = "ppp0";
    # Serve UPnP IGD and PCP/NAT-PMP on private and public VLANs only.
    internalIPs = [
      "10.101.1.1/16"
      "10.102.1.1/16"
    ];
    natpmp = true; # enables both NAT-PMP and PCP on UDP 5351
    upnp = true;
  };
}
