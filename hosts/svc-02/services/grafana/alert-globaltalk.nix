# GlobalTalk / AppleTalk alert group.
# Uses Loki log queries rather than Prometheus metrics.
{
  orgId = 1;
  name = "GlobalTalk";
  folder = "Alerts";
  interval = "5m";
  rules = [
    {
      uid = "atalkd-net-mismatch";
      title = "GlobalTalk network collision";
      condition = "C";
      for = "0s";
      noDataState = "OK";
      execErrState = "Error";
      annotations = {
        summary = "AppleTalk daemon on afp-01 is reporting a network collision.";
        description = ''
          atalkd on afp-01 has detected a network/cable range mismatch, indicating
          another device on the network is advertising conflicting AppleTalk zone
          information. Check for rogue routers or misconfigured devices on the
          AppleTalk segment.
        '';
      };
      labels.severity = "warning";
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
            expr = ''count(rate({host="afp-01", unit="atalkd.service"} |~ `rtmp_packet (last|first)net mismatch (\d*)!=(\d*)` [5m]))'';
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
                  params = [ 1 ];
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
