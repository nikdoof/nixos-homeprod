{ config, ... }:
{
  age.secrets.tailscaleAuthKey = {
    file = ../../../secrets/tailscaleAuthKey.age;
  };

  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscaleAuthKey.path;
    openFirewall = false;
    useRoutingFeatures = "server";
    extraUpFlags = [
      "--advertise-routes=10.0.0.0/8,2001:8b0:bd9::/48,fddd:d00f:dab0::/48"
      "--advertise-exit-node"
      "--login-server=https://hs.doofnet.uk"
    ];
    extraDaemonFlags = [
      "--no-logs-no-support"
    ];
  };
}
