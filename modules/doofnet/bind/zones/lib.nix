{
  internalNS = [
    "ns-01.int.doofnet.uk."
    "ns-02.int.doofnet.uk."
  ];

  publicNS = [
    "ns-03.doofnet.uk."
    "ns-04.doofnet.uk."
  ];

  # Default SOA timing for every zone. Only the serial varies between zones.
  mkSOA = serial: {
    nameServer = "ns-01.int.doofnet.uk.";
    adminEmail = "hostmaster@doofnet.uk";
    inherit serial;
    refresh = 3600;
    retry = 900;
    expire = 604800;
    minimum = 300;
  };
}
