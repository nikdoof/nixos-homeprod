_: {
  services.traefik.dynamicConfigOptions = {
    http = {
      routers = {
        qbittorrent = {
          rule = "Host(`qbittorrent.svc.doofnet.uk`)";
          service = "qbittorrent";
          middlewares = [ "oauth-auth-redirect@file" ];
        };
        nzbget = {
          rule = "Host(`nzbget.svc.doofnet.uk`)";
          service = "nzbget";
          middlewares = [ "oauth-auth-redirect@file" ];
        };
      };

      services = {
        qbittorrent.loadBalancer.servers = [
          { url = "http://10.101.3.16:30024"; }
        ];
        nzbget.loadBalancer.servers = [
          { url = "http://10.101.3.16:6789"; }
        ];
      };
    };
  };
}
