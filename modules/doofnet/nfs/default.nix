{
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.doofnet.nfs;
  server_hostname = "nas-03.int.doofnet.uk";
  nfs_options = [
    "rw"
    "noatime"
    "nfsvers=4"
    "proto=tcp"
  ];
in
{
  options.doofnet.nfs = {
    media = mkEnableOption "Media NFS Mount";
    photos = mkEnableOption "Photos NFS Mount";
    paperless = mkEnableOption "Paperless NFS Mount";
  };

  config = {
    # Media
    fileSystems."/mnt/nas-03/media" = mkIf cfg.media {
      device = "${server_hostname}:/mnt/media";
      fsType = "nfs";
      options = nfs_options;
    };

    # Photos
    fileSystems."/mnt/nas-03/photos" = mkIf cfg.photos {
      device = "${server_hostname}:/mnt/tank02/photos";
      fsType = "nfs";
      options = nfs_options;
    };

    # Paperless
    fileSystems."/mnt/nas-03/paperless" = mkIf cfg.paperless {
      device = "${server_hostname}:/mnt/ssd-mirror/shares/paperless";
      fsType = "nfs";
      options = nfs_options;
    };
  };
}
