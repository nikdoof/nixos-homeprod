_: {
  # Direct external
  services.traefik = {
    dynamicConfigOptions = {
      http = {
        routers.globaltalk = {
          rule = "Host(`globaltalk.doofnet.uk`)";
          service = "globaltalk";
          entrypoints = [
            "websecure"
            "extwebsecure"
          ];
        };

        services.globaltalk.loadBalancer.servers = [
          { url = "http://grf-01.int.doofnet.uk:3000"; }
        ];
      };
    };
  };
}
