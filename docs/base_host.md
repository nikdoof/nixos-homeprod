# Base Host configuration

## Hardware

Hardware is being repurposed from the old Kubernetes worker nodes.

| Device               | Count | OS disk     | Data disk(s)          | RAM   | OS            | Purpose                          |
| -------------------- | ----- | ----------- | --------------------- | ----- | ------------- | -------------------------------- |
| HP Prodesk 600 G3 DM | 1     | 128 GB SATA |                       | 16 GB | NixOS 25.11   |                                  |

## Storage

### Local Storage

All local storage should be provided under `/srv`

* `/srv/data` - Local SSD storage, mapped to the NVMe/Data Disk
  * `/srv/data/<application>` - Per application folder
    * `/srv/data/<application>/<mount>` - Per application mount point, e.g. `/srv/data/sonarr/config`
* `/srv/cluster` - Clustered storage, e.g. CephFS, GlusterFS, etc. Not mounted directly

### Remote Storage

Mounts for remote storage should be placed under `/mnt`, ideally using NFSv4 or whatever cluster-native mounting protocol is available.

* `/mnt/<hostname>/<share>` - Mounted network storage and clustered storage, e.g. `/mnt/nas-03/media`

## Backups

Backups are managed by `borgmatic` and stored on a remote server. Only files under `/srv/data` should be backed up.

## Monitoring

* Prometheus node exporter for host metrics
