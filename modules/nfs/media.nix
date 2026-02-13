{ ... }:

{
  # Media
  fileSystems."/mnt/nas-03/media" = {
    device = "nas-03.int.doofnet.uk:/mnt/media";
    fsType = "nfs";
    options = [
      "rw"
      "noatime"
      "nfsvers=4"
      "proto=tcp"
    ];
  };
}
