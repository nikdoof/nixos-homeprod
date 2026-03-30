{ config, pkgs, ... }:

let
  # Base config without the TSIG secret (safe in /nix/store).
  # ExecStartPre injects the secret from the age-decrypted file at service start.
  ddnsConfigBase = {
    DhcpDdns = {
      ip-address = "127.0.0.1";
      port = 53001;
      dns-server-timeout = 100;
      ncr-protocol = "UDP";
      ncr-format = "JSON";

      tsig-keys = [ ]; # injected at runtime

      forward-ddns.ddns-domains = [
        {
          name = "int.doofnet.uk.";
          key-name = "doofnet-dhcp-updates";
          dns-servers = [
            {
              ip-address = "10.101.1.2";
              port = 53;
            }
          ];
        }
        {
          name = "pub.doofnet.uk.";
          key-name = "doofnet-dhcp-updates";
          dns-servers = [
            {
              ip-address = "10.101.1.2";
              port = 53;
            }
          ];
        }
        {
          name = "lab.doofnet.uk.";
          key-name = "doofnet-dhcp-updates";
          dns-servers = [
            {
              ip-address = "10.101.1.2";
              port = 53;
            }
          ];
        }
        {
          name = "ha.doofnet.uk.";
          key-name = "doofnet-dhcp-updates";
          dns-servers = [
            {
              ip-address = "10.101.1.2";
              port = 53;
            }
          ];
        }
      ];

      reverse-ddns.ddns-domains = [
        # IPv4 reverse zones
        {
          name = "101.10.in-addr.arpa.";
          key-name = "doofnet-dhcp-updates";
          dns-servers = [
            {
              ip-address = "10.101.1.2";
              port = 53;
            }
          ];
        }
        {
          name = "102.10.in-addr.arpa.";
          key-name = "doofnet-dhcp-updates";
          dns-servers = [
            {
              ip-address = "10.101.1.2";
              port = 53;
            }
          ];
        }
        {
          name = "104.10.in-addr.arpa.";
          key-name = "doofnet-dhcp-updates";
          dns-servers = [
            {
              ip-address = "10.101.1.2";
              port = 53;
            }
          ];
        }
        {
          name = "105.10.in-addr.arpa.";
          key-name = "doofnet-dhcp-updates";
          dns-servers = [
            {
              ip-address = "10.101.1.2";
              port = 53;
            }
          ];
        }
        # IPv6 reverse zones
        {
          name = "1.0.1.0.9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa.";
          key-name = "doofnet-dhcp-updates";
          dns-servers = [
            {
              ip-address = "10.101.1.2";
              port = 53;
            }
          ];
        }
        {
          name = "2.0.1.0.9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa.";
          key-name = "doofnet-dhcp-updates";
          dns-servers = [
            {
              ip-address = "10.101.1.2";
              port = 53;
            }
          ];
        }
        {
          name = "4.0.1.0.9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa.";
          key-name = "doofnet-dhcp-updates";
          dns-servers = [
            {
              ip-address = "10.101.1.2";
              port = 53;
            }
          ];
        }
        {
          name = "6.0.1.0.9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa.";
          key-name = "doofnet-dhcp-updates";
          dns-servers = [
            {
              ip-address = "10.101.1.2";
              port = 53;
            }
          ];
        }
      ];
    };
  };

  ddnsConfigBaseFile = (pkgs.formats.json { }).generate "kea-dhcp-ddns-base.json" ddnsConfigBase;

  injectTsig = pkgs.writeShellScript "kea-ddns-inject-tsig" ''
    set -euo pipefail
    secret=$(cat ${config.age.secrets.doofnetDhcpUpdateKeyRaw.path})
    ${pkgs.jq}/bin/jq --arg secret "$secret" \
      '.DhcpDdns["tsig-keys"] = [{"name":"doofnet-dhcp-updates","algorithm":"HMAC-SHA256","secret":$secret}]' \
      ${ddnsConfigBaseFile} > /var/lib/kea/dhcp-ddns.conf
  '';
in
{
  age.secrets.doofnetDhcpUpdateKeyRaw = {
    file = ../../../secrets/doofnetDhcpUpdateKeyRaw.age;
    owner = "kea";
  };

  # configFile points to the runtime-generated file (not the Nix store).
  # The base config in the Nix store has an empty tsig-keys array;
  # ExecStartPre injects the real secret before the daemon starts.
  services.kea.dhcp-ddns = {
    enable = true;
    configFile = "/var/lib/kea/dhcp-ddns.conf";
  };

  systemd.services.kea-dhcp-ddns.serviceConfig.ExecStartPre = toString injectTsig;
}
