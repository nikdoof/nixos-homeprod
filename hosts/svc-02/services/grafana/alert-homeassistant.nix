mkPromData: {
  orgId = 1;
  name = "Home Assistant";
  folder = "Alerts";
  interval = "1m";
  rules = [
    {
      uid = "ha-thread-device-unavailable";
      title = "Thread Device Unavailable";
      condition = "C";
      for = "5m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "Thread device unavailable: {{ $labels.friendly_name }}";
        description = ''
          Home Assistant entity {{ $labels.friendly_name }} ({{ $labels.entity }})
          has been unavailable for more than 5 minutes. The device may have lost
          connectivity to the Thread network or Home Assistant.
        '';
      };
      data = mkPromData {
        expr = ''homeassistant_entity_available{entity=~".*myggspray.*occupancy.*"}'';
        threshold = 1;
        thresholdType = "lt";
      };
    }
  ];
}
