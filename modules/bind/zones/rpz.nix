{
  dns,
  dns_masters,
  dns_slaves,
  ...
}:
{
  master = false;
  masters = dns_masters;
  slaves = dns_slaves;
  file = dns.lib.toString "rpz" {
    SOA = {
      nameServer = (builtins.head dns_masters);
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2019030800;
    };
    NS = dns_masters;

    # RPZ (Response Policy Zone) format:
    # Define domains you want to override as subdomains with A/AAAA records
    # The domain names in RPZ should be the FQDN you want to override
    # For example: "example.com.rpz" would override queries for "example.com"

    subdomains = {
      # Override k8s-prod-ingress-external.doofnet.uk to resolve to 10.101.10.6
      "k8s-prod-ingress-external.doofnet.uk".A = [ "10.101.10.6" ];

      # Override svc-prod-ingress-external.doofnet.uk to resolve to 10.101.3.20
      "svc-prod-ingress-external.doofnet.uk".A = [ "10.101.3.20" ];

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
