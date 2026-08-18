_: {
  services.traefik = {
    dynamicConfigOptions = {
      http = {
        routers.foundryvtt = {
          rule = "Host(`vtt.doofnet.uk`)";
          service = "foundryvtt";
          entrypoints = [
            "websecure"
            "extwebsecure"
          ];
        };

        services.foundryvtt.loadBalancer.servers = [
          { url = "http://fvtt-01.int.doofnet.uk:30000"; }
        ];
      };
    };
  };
}
