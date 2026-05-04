{ config, ... }:
{
  virtualisation.oci-containers.containers.hcloud_exporter = {
    image = "ghcr.io/promhippie/hcloud-exporter:3.14.0";
    environment = {
      HCLOUD_EXPORTER_COLLECTOR_STORAGEBOXES = "true";
    };
    environmentFiles = [
      config.age.secrets.hcloudExporterEnvironment.path
    ];
    ports = [ "9501:9501" ];
  };
  age.secrets.hcloudExporterEnvironment = {
    file = ../../../secrets/hcloudExporterEnvironment.age;
  };

  # Alloy config
  environment.etc."alloy/conf.d/02-hcloud.alloy".text = ''
    prometheus.scrape "hcloud" {
      targets    = [{"__address__" = "127.0.0.1:9501"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "hcloud"
    }
  '';

}
