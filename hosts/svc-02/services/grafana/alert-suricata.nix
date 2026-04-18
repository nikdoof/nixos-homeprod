# Suricata IDS alert group: active exploit detection on vlan-hosted.
# Uses Loki log queries against EVE JSON shipped by Alloy from gw.
#
# All three rules target *actively-exploited* traffic only:
#   - Rule 1: Exploit-tagged rules with Major/Critical signature severity.
#   - Rule 2: Alerts carrying a CVE reference (confirmed vuln exploitation).
#   - Rule 3: Sustained exploit burst (10+ events in 15 min — campaign indicator).
#
# Deliberately excluded: scan/recon events, low/medium severity alerts,
# alerts without the "Exploit" tag, and protocol anomaly detections.
{
  orgId = 1;
  name = "Suricata";
  folder = "Alerts";
  interval = "5m";
  rules = [
    # -----------------------------------------------------------------------
    # Rule 1 — Exploit-tagged alert with Major or Critical severity
    # Fires the moment Suricata sees a high-confidence exploit attempt.
    # -----------------------------------------------------------------------
    {
      uid = "suricata-exploit-major";
      title = "Suricata: Active Exploit Detected (Major/Critical)";
      condition = "C";
      for = "0s";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "Suricata has detected an active exploit attempt on the hosted VLAN";
        description = ''
          Suricata on gw has matched an Emerging Threats "Exploit"-tagged rule
          with Major or Critical signature severity against traffic on vlan-hosted
          in the last 5 minutes.

          These rules fire on specific exploit payloads or shellcode — not
          generic scanning. Review the Loki stream for details:
            {job="suricata", host="gw"}

          Key fields to check in eve.json:
            alert.signature  — rule name
            alert.metadata.cve — CVE if applicable
            src_ip / dest_ip — source and target of the exploit
            http.hostname / http.url — if HTTP-based

          Run on gw: journalctl -u suricata --since "5 min ago"
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
            # Match lines that contain both:
            #   "tag":["Exploit"]  — ET Open Exploit-category rule
            #   "signature_severity":["Major"] or ["Critical"]
            # This avoids false positives from rule names containing "Major".
            expr = ''
              sum(
                count_over_time(
                  {job="suricata", host="gw"}
                    |= `"tag":["Exploit"]`
                    |~ `"signature_severity":\["(Major|Critical)"\]`
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
    # Rule 2 — Alert with CVE metadata (known vulnerability exploitation)
    # Any Suricata alert referencing a specific CVE is high-confidence.
    # -----------------------------------------------------------------------
    {
      uid = "suricata-cve-exploit";
      title = "Suricata: Known CVE Exploit Attempt";
      condition = "C";
      for = "0s";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "Suricata detected traffic matching a rule with a CVE reference";
        description = ''
          Suricata on gw has matched an Emerging Threats rule that carries a
          specific CVE identifier, indicating targeted exploitation of a known
          vulnerability against hosts on vlan-hosted.

          Review the Loki stream for details:
            {job="suricata", host="gw"} |= "cve"

          Key fields:
            alert.metadata.cve — the CVE being exploited
            alert.signature    — rule that fired
            src_ip / dest_ip   — attacker / victim
            http.*, tls.*      — protocol context

          Cross-reference the CVE at nvd.nist.gov to understand scope
          and determine whether affected software is running on the target.
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
            # "cve":[ only appears in metadata when the ET rule has a CVE field.
            # This is a structural JSON match, not a text search.
            expr = ''
              sum(
                count_over_time(
                  {job="suricata", host="gw"}
                    |= `"cve":[`
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
    # Rule 3 — Sustained exploit burst (campaign indicator)
    # More than 10 Exploit-tagged alerts in 15 minutes suggests an active,
    # multi-attempt campaign rather than a one-off probe.
    # -----------------------------------------------------------------------
    {
      uid = "suricata-exploit-burst";
      title = "Suricata: Sustained Exploit Campaign Detected";
      condition = "C";
      for = "0s";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "Suricata is seeing a high volume of exploit alerts — possible active campaign";
        description = ''
          Suricata on gw has matched more than 10 Exploit-tagged rules in the
          last 15 minutes. This volume is consistent with an automated exploit
          campaign or worm-like activity targeting hosts on vlan-hosted.

          Review the Loki stream for attacker IPs and targeted signatures:
            {job="suricata", host="gw"} |= "Exploit"

          Consider temporarily blocking the source IP(s) at the firewall if
          this appears to be targeted rather than background internet noise.

          Alert count in window: {{ $values.B.Value }}
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
            expr = ''
              sum(
                count_over_time(
                  {job="suricata", host="gw"}
                    |= `"tag":["Exploit"]`
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
                  params = [ 10 ];
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
