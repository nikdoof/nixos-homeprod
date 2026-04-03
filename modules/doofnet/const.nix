let
  # Internal, RFC non-public ranges
  internalNetworks = [
    "10.0.0.0/8"
    "fddd:d00f:dab0::/48"
  ];

  # Internal routable ranges
  routeableNetworks = [
    "2001:8b0:bd9::/48"
    "217.169.25.8/29"
    "81.187.48.147/32"
  ];

  # Networks used by tailscale
  tailscaleNetworks = [
    "100.64.0.0/10"
    "fd7a:115c:a1e0::/48"
  ];

  # All networks combined
  allNetworks = internalNetworks ++ routeableNetworks ++ tailscaleNetworks;
in
{
  inherit
    internalNetworks
    routeableNetworks
    tailscaleNetworks
    allNetworks
    ;
}
