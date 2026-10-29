{ pkgs, ... }:
let
  configFile = pkgs.writeText "recyclarr.yml" ''
    radarr:
      movies:
        base_url: http://127.0.0.1:7878
        api_key: !env_var RADARR_API_KEY
        quality_definition:
          type: movie
        delete_old_custom_formats: false
        custom_formats:
          - trash_ids:
              - ed38b889b31be83fda192888e2286d83 # BR-DISK
              - 90cedc1fea7ea5d11298bebd3d1d3223 # EVO (no WEBDL)
              - 90a6f9a284dff5103f6346090e6280c8 # LQ
              - dc98083864ea246d05a42df0d05f81cc # x265 (720/1080p)
              - b8cd450cbfa689c0259a01d9e29ba3d6 # 3D

    sonarr:
      series:
        base_url: http://127.0.0.1:8989
        api_key: !env_var SONARR_API_KEY
        quality_definition:
          type: series
        custom_formats:
          - trash_ids:
              # Unwanted
              - 85c61753df5da1fb2aab6f2a47426b09 # BR-DISK
              - 9c11cd3f07101cdba90a2d81cf0e56b4 # LQ
              - 47435ece6b99a0b477caf360e79ba0bb # x265
              # Misc
              - ec8fa7296b64e8cd390a1600981f3923 # Repack/Proper
              - eb3d5cc0a2be0db205fb823640db6a3c # Repack v2
              - 44e7c4de10ae50265753082e5dc76047 # Repack v3
              # Streaming Services
              - d660701077794679fd59e8bdf4ce3a29 # AMZN
              - f67c9ca88f463a48346062e8ad07713f # ATVP
              - 36b72f59f4ea20aad9316f475f2d9fbb # DCU
              - 89358767a60cc28783cdc3d0be9388a4 # DNSP
              - 7a235133c87f7da4c8cccceca7e3c7a6 # HBO
              - a880d6abc21e7c16884f3ae393f84179 # HMAX
              - f6cce30f1733d5c8194222a7507909bb # HULU
              - 0ac24a2a68a9700bcb7eeca8e5cd644c # iT
              - d34870697c9db575f17700212167be23 # NF
              - b2b980877494b560443631eb1f473867 # NLZ
              - 1656adc6d7bb2c8cca6acfb6592db421 # PCOK
              - c67a75ae4a1715f2bb4d492755ba4195 # PMTP
              - 3ac5d84fce98bab1b531393e9c82f467 # QIBI
              - c30d2958827d1867c73318a5a2957eb1 # RED
              - ae58039e1319178e6be73caab5c42166 # SHO
              - 1efe8da11bfd74fbbcd4d8117ddb9213 # STAN
              - 5d2317d99af813b6529c7ebf01c83533 # VDL
              - 77a7b25585c18af08f60b1547bb9b4fb # CC
              # HQ Source Groups
              - e6258996055b9fbab7e9cb2f75819294 # WEB Tier 01
              - 58790d4e2fdcd9733aa7ae68ba2bb503 # WEB Tier 02
              - d84935abd3f8556dcd51d4f27e22d0a6 # WEB Tier 03
              - d0c516558625b04b363fa6c5c2c7cfd4 # WEB Scene
            assign_scores_to:
              - name: WEB 1080p / 720p
  '';
in
{
  systemd.timers.recyclarr = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };

  systemd.services.recyclarr = {
    description = "Daily Recyclarr sync for Radarr and Sonarr";
    after = [
      "podman-radarr.service"
      "podman-sonarr.service"
    ];
    wants = [
      "podman-radarr.service"
      "podman-sonarr.service"
    ];

    script = ''
      radarr_api_key="$(${pkgs.xmlstarlet}/bin/xmlstarlet sel -t -v '/Config/ApiKey' /srv/data/radarr/config/config.xml)"
      sonarr_api_key="$(${pkgs.xmlstarlet}/bin/xmlstarlet sel -t -v '/Config/ApiKey' /srv/data/sonarr/config/config.xml)"

      if [ -z "$radarr_api_key" ] || [ -z "$sonarr_api_key" ]; then
        echo "Could not read the Radarr or Sonarr API key from its config.xml" >&2
        exit 1
      fi

      export RADARR_API_KEY="$radarr_api_key"
      export SONARR_API_KEY="$sonarr_api_key"

      exec ${pkgs.recyclarr}/bin/recyclarr sync --config ${configFile}
    '';

    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "recyclarr";
      StateDirectoryMode = "0700";
      Environment = [
        "RECYCLARR_CONFIG_DIR=/var/lib/recyclarr"
        "RECYCLARR_DATA_DIR=/var/lib/recyclarr"
        "NO_COLOR=1"
      ];
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      PrivateTmp = true;
      PrivateDevices = true;
      RestrictSUIDSGID = true;
      CapabilityBoundingSet = "";
    };
  };
}
