{ ... }:

{
  # Media
  fileSystems."/mnt/nas-03/paperless" = {
    device = "nas-03.int.doofnet.uk:/mnt/ssd-mirror/shares/paperless";
    fsType = "nfs";
    options = [
      "rw"
      "noatime"
      "nfsvers=4"
      "proto=tcp"
    ];
  };
}
