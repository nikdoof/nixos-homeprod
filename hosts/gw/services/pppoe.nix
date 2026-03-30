_: {
  # Deploy credentials to the path pppd reads at startup.
  # File format: "username" * "password"
  age.secrets.pppoeCredentials = {
    file = ../../../secrets/pppoeCredentials.age;
    path = "/etc/ppp/pap-secrets";
    owner = "root";
    mode = "0600";
  };

  services.pppd = {
    enable = true;
    peers.aaisp = {
      autostart = true;
      enable = true;
      config = ''
        plugin pppoe.so vlan-wan
        user "aw143@a.2"
        noauth
        defaultroute
        defaultroute6
        persist
        mtu 1500
        mru 1500
        lcp-echo-interval 30
        lcp-echo-failure 4
      '';
    };
  };

  # pppd must start after vlan-wan exists
  systemd.services."ppp-aaisp".after = [ "sys-subsystem-net-devices-vlan\\x2dwan.device" ];
  systemd.services."ppp-aaisp".requires = [ "sys-subsystem-net-devices-vlan\\x2dwan.device" ];
}
