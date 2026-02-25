{
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.doofnet.nfs;
in
{
  options.doofnet.nfs = {
    media = mkEnableOption "Media NFS Mount";
    photos = mkEnableOption "Photos NFS Mount";
    paperless = mkEnableOption "Paperless NFS Mount";
  };

  config = {
    # Media
    fileSystems."/mnt/nas-03/media" = mkIf cfg.doofnet.nfs.media {
      device = "nas-03.int.doofnet.uk:/mnt/media";
      fsType = "nfs";
      options = [
        "rw"
        "noatime"
        "nfsvers=4"
        "proto=tcp"
      ];
    };

    # Photos
    fileSystems."/mnt/nas-03/photos" = mkIf cfg.doofnet.nfs.photos {
      device = "nas-03.int.doofnet.uk:/mnt/tank02/photos";
      fsType = "nfs";
      options = [
        "rw"
        "noatime"
        "nfsvers=4"
        "proto=tcp"
      ];
    };

    # Paperless
    fileSystems."/mnt/nas-03/paperless" = mkIf cfg.doofnet.nfs.paperless {
      device = "nas-03.int.doofnet.uk:/mnt/ssd-mirror/shares/paperless";
      fsType = "nfs";
      options = [
        "rw"
        "noatime"
        "nfsvers=4"
        "proto=tcp"
      ];
    };
  };
}
