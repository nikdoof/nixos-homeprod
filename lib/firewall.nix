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

  # Build a single iptables/ip6tables rule for one subnet.
  # action should be "-A" (append) or "-D" (delete).
  mkRule =
    cmd: action: port: comment: subnet:
    "${cmd} ${action} nixos-fw -p tcp -m tcp --dport ${toString port} -s ${subnet} -j nixos-fw-accept -m comment --comment \"${comment}\"";

  # Build the full set of add rules for all Prometheus subnets.
  mkAddRules =
    port: comment:
    lib.concatStringsSep "\n" (
      [ (mkRule "iptables" "-A" port comment prometheusSubnets.ipv4) ]
      ++ map (mkRule "ip6tables" "-A" port comment) prometheusSubnets.ipv6
    );

  # Build the full set of delete rules for all Prometheus subnets.
  # Each delete is guarded so it only fires when the rule actually exists,
  # making it safe to run multiple times without erroring.
  mkDelRules =
    port: comment:
    lib.concatStringsSep "\n" (
      map (rule: "iptables -C ${lib.removePrefix "iptables -A " rule} 2>/dev/null && ${rule}") [
        (mkRule "iptables" "-D" port comment prometheusSubnets.ipv4)
      ]
      ++ map (rule: "ip6tables -C ${lib.removePrefix "ip6tables -A " rule} 2>/dev/null && ${rule}") (
        map (mkRule "ip6tables" "-D" port comment) prometheusSubnets.ipv6
      )
    );

in
{
  # allowFromPrometheus :: int -> string -> attrset
  #
  # Returns a networking.firewall attrset that permits TCP traffic on `port`
  # from the internal Prometheus scraper subnets only.  The result is suitable
  # for direct assignment or for use inside lib.mkMerge.
  #
  # extraStopCommands mirrors every rule added by extraCommands with a
  # corresponding delete, so rules do not accumulate across nixos-rebuild
  # switch invocations.
  #
  # Arguments:
  #   port    - TCP port the exporter listens on
  #   comment - iptables comment string (use the exporter name, e.g. "node_exporter")
  allowFromPrometheus = port: comment: {
    extraCommands = mkAddRules port comment;
    extraStopCommands = mkDelRules port comment;
  };
}
