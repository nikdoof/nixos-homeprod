{ ... }:

{
  # Media
  fileSystems."/mnt/nas-03/photos" = {
    device = "nas-03.int.doofnet.uk:/mnt/photos";
    fsType = "nfs";
    options = [
      "rw"
      "noatime"
      "nfsvers=4"
      "proto=tcp"
    ];
  };
}
