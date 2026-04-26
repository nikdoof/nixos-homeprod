{ zlib, ... }:
{
  zoneData = {
    SOA = zlib.mkSOA 2026031301;
    NS = zlib.internalNS;
    # RPZ (Response Policy Zone) format:
    # Define domains you want to override as subdomains with A/AAAA records
    # The domain names in RPZ should be the FQDN you want to override
    # For example: "example.com.rpz" would override queries for "example.com"

    subdomains = {
      # Override svc-prod-ingress-external.doofnet.uk to resolve to 10.101.3.20
      "svc-prod-ingress-external.doofnet.uk".A = [ "10.101.3.20" ];

      # Redirect metrics.doofnet.uk to svc-01 internally so Alloy on internal
      # hosts hits Traefik directly rather than going via the public IP.
      "metrics.doofnet.uk".A = [ "10.101.3.20" ];

      "tester.mfg.cobaltmicro.com".A = [ "10.101.3.104" ];
      # You can also use CNAME to special RPZ actions:
      # - "." means NXDOMAIN (block the domain)
      # - "*." means NODATA (domain exists but no records)
      # - "rpz-passthru." means exempt from policy
      # - "rpz-drop." means drop the query silently
      # - "rpz-tcp-only." means respond only to TCP queries
      #
      # Example blocking a domain:
      # "blocked-site.com".CNAME = [ "." ];

      # Example allowing a domain to bypass RPZ:
      # "trusted-site.com".CNAME = [ "rpz-passthru." ];
    };
  };
}
