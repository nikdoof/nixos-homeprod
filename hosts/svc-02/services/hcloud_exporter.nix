{ config, ... }:
{
  virtualisation.oci-containers.containers.hcloud_exporter = {
    image = "ghcr.io/promhippie/hcloud-exporter:3.10.0";
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
}
