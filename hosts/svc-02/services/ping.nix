_: {
  services.prometheus.exporters.ping = {
    enable = true;
    port = 9427;
    listenAddress = "127.0.0.1";
    settings = {
      targets = [
        "gw.int.doofnet.uk"
        "hyp-01.int.doofnet.uk"
        "nas-03.int.doofnet.uk"
        "ns-01.int.doofnet.uk"
        "ns-02.int.doofnet.uk"
        "svc-01.int.doofnet.uk"
        "81.187.81.187"
        "google.com"
      ];
    };
  };

  environment.etc."alloy/conf.d/02-ping.alloy".text = ''
    prometheus.scrape "ping" {
      targets    = [{"__address__" = "localhost:9427"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "ping"
    }
  '';
}
