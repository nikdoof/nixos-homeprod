_: {
  # miniupnpd with nftables backend. The NixOS module already selects the
  # nftables build automatically when networking.nftables.enable is true
  # (via pkgs.miniupnpd.override { firewall = "nftables"; }), so no overlay
  # is needed. miniupnpd manages its own `miniupnpd` nftables table at runtime
  # for port mapping rules; it does not touch our `inet filter` or `ip nat` tables.

  services.miniupnpd = {
    enable = true;
    externalInterface = "ppp0";
    # miniupnpd-nftables requires interface names here, not IP addresses.
    internalIPs = [
      "vlan-private"
      "vlan-public"
    ];
    natpmp = true; # enables both NAT-PMP and PCP on UDP 5351
    upnp = true;
    # Restrict port mapping to private and public VLAN ranges only.
    # miniupnpd evaluates allow/deny lines top-to-bottom; explicit deny at end
    # ensures hosts outside these ranges cannot create mappings.
    appendConfig = ''
      # secure_mode: a client can only request a port mapping whose internal
      # IP matches its own source IP. Without this, any host on vlan-public
      # could open ports forwarding to an arbitrary internal host.
      secure_mode=yes

      # Don't probe external STUN servers to detect NAT behaviour; we know
      # we're behind a single plain NAT (ppp0) and the probe leaks the
      # router's presence to a third party.
      ext_perform_stun=no

      # Report system uptime rather than the miniupnpd service uptime to
      # clients; less interesting to an attacker profiling the box.
      system_uptime=no

      allow 1024-65535 10.101.0.0/16 1024-65535
      allow 1024-65535 10.102.0.0/16 1024-65535
      deny 0-65535 0.0.0.0/0 0-65535
    '';
  };
}
