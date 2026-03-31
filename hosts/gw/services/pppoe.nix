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

        noipdefault
        defaultroute
        hide-password
        lcp-echo-interval 1
        lcp-echo-failure 10
        noauth
        persist
        maxfail 0
        mtu 1500
        noaccomp
        default-asyncmap
        +ipv6
        ipv6cp-use-ipaddr
      '';
    };
  };

  # pppd must start after vlan-wan exists
  systemd.services."ppp-aaisp".after = [ "sys-subsystem-net-devices-vlan\\x2dwan.device" ];
  systemd.services."ppp-aaisp".requires = [ "sys-subsystem-net-devices-vlan\\x2dwan.device" ];
}
