# Suricata compromise-detection alert group.
# Fires when a hosted-VLAN IP (217.169.25.8/29 or 2001:8b0:bd9:106::/64)
# appears as *src_ip* in a Suricata alert — meaning one of our own servers
# is the source of malicious traffic rather than the target.
#
# This is the strongest available indicator of host compromise:
# ET Open rules are written from a network-wide perspective, so when our
# own IP is the attacker, something on that host is actively malicious.
#
# Three escalating rules:
#   1. Internal host running exploits (highest confidence, fires immediately)
#   2. Internal host connecting to C2/malware infrastructure
#   3. Any alert with internal src_ip, sustained volume (lateral movement)
{
  orgId = 1;
  name = "Suricata — Compromise";
  folder = "Alerts";
  interval = "5m";
  rules = [
    # -----------------------------------------------------------------------
    # Rule 1 — Internal host as exploit source
    # A hosted-VLAN IP is sending exploit payloads. This is the clearest
    # possible indicator of an actively compromised server.
    # -----------------------------------------------------------------------
    {
      uid = "suricata-internal-exploit-src";
      title = "Suricata: Hosted VLAN Host Sending Exploit Traffic";
      condition = "C";
      for = "0s";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "A hosted-VLAN host is the SOURCE of exploit traffic — possible compromise";
        description = ''
          Suricata on gw has fired an Exploit-tagged rule where the source IP is
          within the hosted VLAN (217.169.25.8/29 or 2001:8b0:bd9:106::/64).

          A hosted server is actively sending exploit payloads. This strongly
          indicates the host has been compromised and is being used to attack
          other systems (lateral movement, worm propagation, or C2-directed attack).

          Investigate immediately:
            1. Identify the source host by IP in the Loki stream:
               {job="suricata", host="gw"} | json | src_ip =~ "217\\.169\\.25\\."
            2. Check what process is generating the traffic:
               ss -tnp on the affected host
            3. Review recent logins and running processes:
               last, ps aux, journalctl --since "1 hour ago"
            4. Consider isolating the host at the firewall while investigating.
        '';
      };
      data = [
        {
          refId = "A";
          datasourceUid = "loki";
          queryType = "instant";
          relativeTimeRange = {
            from = 300;
            to = 0;
          };
          model = {
            refId = "A";
            queryType = "instant";
            datasource = {
              type = "loki";
              uid = "loki";
            };
            # Parse src_ip from EVE JSON and check it against the hosted-VLAN
            # prefixes. The |= pre-filter on "Exploit" narrows the log set
            # before the more expensive JSON parse runs.
            # IPv4: 217.169.25.8/29 = .8–.15
            # IPv6: 2001:8b0:bd9:106::/64 prefix
            expr = ''
              sum(
                count_over_time(
                  {job="suricata", host="gw"}
                    |= `"tag":["Exploit"]`
                    | json
                    | src_ip =~ `(217\.169\.25\.(8|9|1[0-5])|2001:8b0:bd9:106:)`
                  [5m]
                )
              )
            '';
          };
        }
        {
          refId = "B";
          datasourceUid = "__expr__";
          model = {
            refId = "B";
            type = "reduce";
            expression = "A";
            reducer = "last";
            datasource = {
              type = "__expr__";
              uid = "__expr__";
            };
          };
        }
        {
          refId = "C";
          datasourceUid = "__expr__";
          model = {
            refId = "C";
            type = "threshold";
            expression = "B";
            datasource = {
              type = "__expr__";
              uid = "__expr__";
            };
            conditions = [
              {
                evaluator = {
                  params = [ 0 ];
                  type = "gt";
                };
                operator.type = "and";
                query.params = [ "B" ];
                reducer.type = "last";
                type = "query";
              }
            ];
          };
        }
      ];
    }

    # -----------------------------------------------------------------------
    # Rule 2 — Internal host contacting C2 / malware infrastructure
    # Trojans, botnet beaconing, and malware C2 channels where our host
    # initiates the connection to an external controller.
    # -----------------------------------------------------------------------
    {
      uid = "suricata-internal-c2";
      title = "Suricata: Hosted VLAN Host Connecting to C2 / Malware Infrastructure";
      condition = "C";
      for = "0s";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "A hosted-VLAN host is connecting to known C2 or malware infrastructure";
        description = ''
          Suricata on gw has matched a Trojan Activity or Malware C2 rule where
          the source IP is a hosted-VLAN host. The host is initiating contact
          with external infrastructure known to be used by malware or botnets.

          This pattern indicates the host is infected and is beaconing to its
          command-and-control server — a key indicator of a post-compromise
          persistent implant.

          Investigate immediately:
            1. Find the alerting rule and destination in Loki:
               {job="suricata", host="gw"} | json | src_ip =~ "217\\.169\\.25\\."
               Look at alert_signature and dest_ip.
            2. Block the destination IP/domain at the firewall.
            3. Identify the connecting process on the host:
               ss -tnp | grep <dest_ip>
               lsof -i @<dest_ip>
            4. Review running processes and startup entries for persistence.
            5. Isolate the host and preserve logs before remediation.
        '';
      };
      data = [
        {
          refId = "A";
          datasourceUid = "loki";
          queryType = "instant";
          relativeTimeRange = {
            from = 300;
            to = 0;
          };
          model = {
            refId = "A";
            queryType = "instant";
            datasource = {
              type = "loki";
              uid = "loki";
            };
            # Pre-filter on C2/malware alert categories before JSON parse.
            # ET Open uses these exact category strings for C2 and trojan rules.
            expr = ''
              sum(
                count_over_time(
                  {job="suricata", host="gw"}
                    |~ `"category":"(Trojan Activity|A Network Trojan was Detected|Malware Command and Control Activity Detected)"`
                    | json
                    | src_ip =~ `(217\.169\.25\.(8|9|1[0-5])|2001:8b0:bd9:106:)`
                  [5m]
                )
              )
            '';
          };
        }
        {
          refId = "B";
          datasourceUid = "__expr__";
          model = {
            refId = "B";
            type = "reduce";
            expression = "A";
            reducer = "last";
            datasource = {
              type = "__expr__";
              uid = "__expr__";
            };
          };
        }
        {
          refId = "C";
          datasourceUid = "__expr__";
          model = {
            refId = "C";
            type = "threshold";
            expression = "B";
            datasource = {
              type = "__expr__";
              uid = "__expr__";
            };
            conditions = [
              {
                evaluator = {
                  params = [ 0 ];
                  type = "gt";
                };
                operator.type = "and";
                query.params = [ "B" ];
                reducer.type = "last";
                type = "query";
              }
            ];
          };
        }
      ];
    }

    # -----------------------------------------------------------------------
    # Rule 3 — Lateral movement / sustained internal-source alert volume
    # Any alert category where a hosted-VLAN IP is the source, sustained
    # over 15 minutes. Catches broader compromise patterns not covered by
    # rules 1 and 2: port scanning from compromised host, brute-force
    # originating internally, worm propagation, etc.
    # -----------------------------------------------------------------------
    {
      uid = "suricata-internal-lateral";
      title = "Suricata: Sustained Malicious Activity Originating from Hosted VLAN";
      condition = "C";
      for = "0s";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "Multiple alerts with a hosted-VLAN host as source — possible lateral movement";
        description = ''
          Suricata on gw has generated more than 5 alerts where a hosted-VLAN IP
          is the source in the last 15 minutes. The alerts may span multiple
          categories (scan, exploit, policy, trojan).

          Volume of internal-source alerts sustained for 15 minutes suggests
          active malicious activity from a compromised host — lateral movement,
          internal scanning, or worm propagation.

          Alert count in window: {{ $values.B.Value }}

          Investigate:
            1. Find which host(s) are sourcing alerts:
               {job="suricata", host="gw"} | json | src_ip =~ "217\\.169\\.25\\."
               Group by src_ip and alert_signature.
            2. Look for patterns: same dest_port (port scan), same dest_ip
               (targeted attack), or varied targets (worm).
            3. Review the host for new processes, scheduled tasks, modified files.
        '';
      };
      data = [
        {
          refId = "A";
          datasourceUid = "loki";
          queryType = "instant";
          relativeTimeRange = {
            from = 900;
            to = 0;
          };
          model = {
            refId = "A";
            queryType = "instant";
            datasource = {
              type = "loki";
              uid = "loki";
            };
            # No category pre-filter here — any alert from an internal source
            # over a 15-minute window is worth flagging if volume exceeds 5.
            expr = ''
              sum(
                count_over_time(
                  {job="suricata", host="gw"}
                    | json
                    | src_ip =~ `(217\.169\.25\.(8|9|1[0-5])|2001:8b0:bd9:106:)`
                  [15m]
                )
              )
            '';
          };
        }
        {
          refId = "B";
          datasourceUid = "__expr__";
          model = {
            refId = "B";
            type = "reduce";
            expression = "A";
            reducer = "last";
            datasource = {
              type = "__expr__";
              uid = "__expr__";
            };
          };
        }
        {
          refId = "C";
          datasourceUid = "__expr__";
          model = {
            refId = "C";
            type = "threshold";
            expression = "B";
            datasource = {
              type = "__expr__";
              uid = "__expr__";
            };
            conditions = [
              {
                evaluator = {
                  params = [ 5 ];
                  type = "gt";
                };
                operator.type = "and";
                query.params = [ "B" ];
                reducer.type = "last";
                type = "query";
              }
            ];
          };
        }
      ];
    }
  ];
}
