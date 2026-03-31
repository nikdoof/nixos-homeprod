_: {
  # lldpd — bidirectional LLDP on physical uplinks only.
  # Restricting to the two physical NICs means switches/neighbours see the
  # gateway itself rather than getting per-VLAN advertisements from every
  # sub-interface.
  services.lldpd = {
    enable = true;
    extraArgs = [
      "-I"
      "enp3s0f0,enp3s0f1"
    ];
  };
}
