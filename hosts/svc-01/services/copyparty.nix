{ config, pkgs, ... }:
let
  copypartyConfig = pkgs.writeText "copyparty.conf" ''
    [global]
       e2dsa
       stats
       e2ts
       rproxy: 1
       nih
       xff-src: 10.88.0.1/32
       ipu: 10.0.0.0/8=doofnet
       no-robots
       ah-alg: argon2
       ah-salt: W1QaLY0tiv1ojx53DkOcc/vy

     [accounts]
       doofnet: +H56hi8d2bMM5fJP3PKX3rMXmoQt7mMV4
       nikdoof: +kaDGcZ8TaoFp5_WZQdsajTg2tsHm55sE
       salkunh: +Yy99cmaRLOj8cnEW89oQVsQ8lCIy8s78
       metrics: +XdQLDeFstloEzhIJ7z5lYsnya_LUUPyQ

     [groups]
       home: doofnet, nikdoof, salkunh

     [/]
       /w
       accs:
         r: *
         a: metrics
         A: @home

     [/inc]
       /w/inc
       accs:
         A: @home
  '';
in
{
  age.secrets.copypartyMetricsPassword = {
    file = ../../../secrets/copypartyMetricsPassword.age;
    mode = "0444";
  };

  virtualisation.oci-containers.containers.copyparty = {
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.copyparty.rule" = "Host(`files.doofnet.uk`)";
      "traefik.http.services.copyparty.loadbalancer.server.port" = "3923";
      "traefik.http.routers.copyparty.entrypoints" = "websecure,extwebsecure";
    };
    image = "ghcr.io/9001/copyparty-ac:1.20.14";
    environment = {
      TZ = "Europe/London";
    };
    ports = [ "127.0.0.1:3923:3923" ];
    volumes = [
      "/srv/data/copyparty/data:/w"
      "${copypartyConfig}:/cfg/doofnet.conf:ro"
    ];
  };

  environment.etc."alloy/conf.d/02-copyparty.alloy".text = ''
    prometheus.scrape "copyparty" {
      targets      = [{"__address__" = "localhost:3923"}]
      forward_to   = [prometheus.remote_write.default.receiver]
      job_name     = "copyparty"
      metrics_path = "/.cpr/metrics"

      basic_auth {
        username      = "metrics"
        password_file = "${config.age.secrets.copypartyMetricsPassword.path}"
      }
    }
  '';

  services.borgmatic.settings.source_directories = [ "/srv/data/copyparty/data" ];
}
