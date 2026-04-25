_: {
  # Home Assistant exposes /api/prometheus on the hs-01 microvm.
  # Scraped from svc-02 via Alloy so the metric pipeline matches every other exporter.
  environment.etc."alloy/conf.d/02-homeassistant.alloy".text = ''
    prometheus.scrape "homeassistant" {
      targets      = [{"__address__" = "homeassistant.int.doofnet.uk:443"}]
      forward_to   = [prometheus.remote_write.default.receiver]
      job_name     = "homeassistant"
      metrics_path = "/api/prometheus"
      scheme       = "https"
    }
  '';
}
