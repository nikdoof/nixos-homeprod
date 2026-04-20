{ config, ... }:
{
  age.secrets = {
    pocketIdEncryptionKey = {
      file = ../../../secrets/pocketIdEncryptionKey.age;
      owner = "1000";
    };
    maxmindLicenseKey = {
      file = ../../../secrets/maxmindLicenseKey.age;
      owner = "1000";
    };
  };

  # Pocket ID
  virtualisation.oci-containers.containers.pocket-id = {
    labels = {
      "traefik.enable" = "true";
      "traefik.http.routers.pocket-id.rule" = "Host(`id.doofnet.uk`)";
      "traefik.http.services.pocket-id.loadbalancer.server.port" = "8081";
      "traefik.http.routers.pocket-id.entrypoints" = "websecure,extwebsecure";
    };
    image = "ghcr.io/pocket-id/pocket-id:v2.6.0";
    volumes = [
      "/srv/data/pocket-id/data:/app/data:U"
      "${config.age.secrets.pocketIdEncryptionKey.path}:/secrets/pocketIdEncryptionKey"
      "${config.age.secrets.maxmindLicenseKey.path}:/secrets/maxmindLicenseKey"
    ];
    environment = {
      APP_URL = "https://id.doofnet.uk";
      ENCRYPTION_KEY_FILE = "/secrets/pocketIdEncryptionKey";
      MAXMIND_LICENSE_KEY_FILE = "/secrets/maxmindLicenseKey";
      METRICS_ENABLED = "true";
      OTEL_EXPORTER_PROMETHEUS_HOST = "0.0.0.0";
      OTEL_METRICS_EXPORTER = "prometheus";
      PORT = "8081";
      TRUST_PROXY = "true";
    };
    # Map host:9465 → container:9464 (OTEL prometheus default) to avoid
    # conflicting with GoToSocial which also uses 9464.
    ports = [ "127.0.0.1:9465:9464" ];
  };

  environment.etc."alloy/conf.d/02-pocket-id.alloy".text = ''
    prometheus.scrape "pocket_id" {
      targets    = [{"__address__" = "localhost:9465"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "pocket_id"
    }
  '';

  services.borgmatic.settings.source_directories = [ "/srv/data/pocket-id/data" ];
}
