{
  zlib,
  ...
}:
{
  # Special-Use Domain Names space (RFC 6761): authoritative empty zone for
  # local resolution.
  zoneData = {
    SOA = zlib.mkSOA 2026031301;
    NS = zlib.internalNS;
  };
}
