_: {
  # Alloy config
  environment.etc."alloy/conf.d/02-blackbox.alloy".text = ''
      prometheus.exporter.blackbox "blackbox" {
        config = "{ modules: { https_2xx: { prober: http, timeout: 10s, http: { valid_status_codes = [], fail_if_not_ssl = true, preferred_ip_protocol = ipv4 } } } }"

        target {
          name    = "social.doofnet.uk"
          address = "https://social.doofnet.uk"
          module  = "https_2xx"
        }
        target {
          name    = "id.doofnet.uk"
          address = "https://id.doofnet.uk"
          module  = "https_2xx"
        }
        target {
          name    = "rss.doofnet.uk"
          address = "https://rss.doofnet.uk"
          module  = "https_2xx"
        }
        target {
          name    = "link.doofnet.uk"
          address = "https://link.doofnet.uk"
          module  = "https_2xx"
        }
        target {
          name    = "doofnet.uk"
          address = "https://doofnet.uk"
          module  = "https_2xx"
        }
        target {
          name    = "nikdoof.com"
          address = "https://nikdoof.com"
          module  = "https_2xx"
        }
      }
    }
  '';
}
