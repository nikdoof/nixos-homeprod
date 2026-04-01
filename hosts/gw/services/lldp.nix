_: {
  # Restrict LLDP to only the trunk port
  services.lldpd.extraArgs = [
    "-I"
    "enp3s0f0"
  ];
}
