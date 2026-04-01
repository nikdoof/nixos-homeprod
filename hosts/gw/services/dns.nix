_: {
  services.unbound = {
    enable = true;
    settings = {
      server = {
        # Listen only on the hosted VLAN interface
        interface = [
          "217.169.25.9"
          "2001:8b0:bd9:106::1"
        ];
        access-control = [
          "0.0.0.0/0 refuse"
          "::/0 refuse"
          "217.169.25.8/29 allow"
          "2001:8b0:bd9:106::/64 allow"
        ];
        do-not-query-localhost = false;
      };
      forward-zone = [
        {
          name = ".";
          forward-addr = [
            "10.101.1.2"
            "10.101.1.3"
            "2001:8b0:bd9:101::2"
            "2001:8b0:bd9:101::3"
          ];
        }
      ];
    };
  };
}
