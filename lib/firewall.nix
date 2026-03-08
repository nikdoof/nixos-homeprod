# lib/firewall.nix
#
# Shared firewall helpers for the doofnet network.
#
# Usage in a module:
#
#   { lib, ... }:
#   let firewall = import ../../lib/firewall.nix { inherit lib; };
#   in {
#     networking.firewall = firewall.allowFromPrometheus 9187 "my-exporter";
#   }
#
# Multiple rules can be merged with lib.mkMerge:
#
#   networking.firewall = lib.mkMerge [
#     { allowedTCPPorts = [ 80 ]; }
#     (firewall.allowFromPrometheus 9187 "my-exporter")
#   ];

{ lib }:

let
  # The IPv4 and IPv6 subnets that the internal Prometheus scraper lives on.
  # Update these if the monitoring infrastructure moves.
  prometheusSubnets = {
    ipv4 = "10.101.0.0/16";
    ipv6 = [
      "fddd:d00f:dab0:101::/64" # ULA
      "2001:8b0:bd9:101::21/64" # GUA
    ];
  };

  # Build a single iptables/ip6tables allow rule for one subnet.
  mkRule =
    cmd: port: comment: subnet:
    "${cmd} -A nixos-fw -p tcp -m tcp --dport ${toString port} -s ${subnet} -j nixos-fw-accept -m comment --comment \"${comment}\"";

in
{
  # allowFromPrometheus :: int -> string -> attrset
  #
  # Returns a networking.firewall attrset that permits TCP traffic on `port`
  # from the internal Prometheus scraper subnets only.  The result is suitable
  # for direct assignment or for use inside lib.mkMerge.
  #
  # Arguments:
  #   port    — TCP port the exporter listens on
  #   comment — iptables comment string (use the exporter name, e.g. "node_exporter")
  allowFromPrometheus = port: comment: {
    extraCommands = lib.concatStringsSep "\n" (
      [ (mkRule "iptables" port comment prometheusSubnets.ipv4) ]
      ++ map (mkRule "ip6tables" port comment) prometheusSubnets.ipv6
    );
  };
}
