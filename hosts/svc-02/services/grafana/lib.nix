# Shared helpers for Grafana alert rule definitions.
{
  # Builds the standard Prometheus A=query / B=reduce / C=threshold data
  # structure used by Grafana unified alerting rules.
  mkPromData =
    {
      expr,
      threshold,
      thresholdType ? "gt",
      rangeFrom ? 600,
    }:
    [
      {
        refId = "A";
        datasourceUid = "prometheus";
        queryType = "";
        relativeTimeRange = {
          from = rangeFrom;
          to = 0;
        };
        model = {
          refId = "A";
          instant = true;
          inherit expr;
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
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
                params = [ threshold ];
                type = thresholdType;
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
