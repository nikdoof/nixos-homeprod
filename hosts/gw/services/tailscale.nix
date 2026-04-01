{ config, ... }:
{
  age.secrets.tailscaleAuthKey = {
    file = ../../../secrets/tailscaleAuthKey.age;
  };

  services.tailscale = {
    enable = true;
    authKeyParameters = {
      baseURL = "https://hs.doofnet.uk";
    };
    authKeyFile = config.age.secrets.tailscaleAuthKey.path;
    openFirewall = false;
    useRoutingFeatures = "server";
    extraUpFlags = [
      "--advertise-routes"
      "10.0.0.0/8"
      "--advertise-exit-node"
    ];
  };
}
