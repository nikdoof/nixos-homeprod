# svc-01: Services Host

svc-01 is the primary services host, running containerised applications via Podman with
Traefik as the reverse proxy for both internal and external traffic.

## Hardware

HP ProDesk 600 G3 DM — see `docs/base_host.md`. Additional hardware includes a Google
Coral TPU (PCIe) for machine learning acceleration.

## Storage

| Mount               | Purpose                                     |
| ------------------- | ------------------------------------------- |
| `/srv/data`         | Local SSD (XFS); application data + configs |
| `/mnt/nas-03/media` | NFS mount from NAS for media content        |

## Services (all Podman containers via Traefik)

| Service       | Domain / Route                 | Purpose                               |
| ------------- | ------------------------------ | ------------------------------------- |
| Mastodon      | `social.doofnet.uk`            | Fediverse microblogging               |
| Gitea         | `git.doofnet.uk`               | Self-hosted Git service               |
| Jellyfin      | `jellyfin.svc.doofnet.uk`      | Media server                          |
| Paperless-ngx | `paperless.svc.doofnet.uk`     | Document management                   |
| Miniflux      | `rss.svc.doofnet.uk`           | RSS reader                            |
| Linkding      | `bookmarks.svc.doofnet.uk`     | Bookmark manager                      |
| Glance        | `start.svc.doofnet.uk`         | Dashboard / startpage                 |
| Copyparty     | `files.svc.doofnet.uk`         | File sharing                          |
| Gotosocial    | `social.gotosocial.doofnet.uk` | Lightweight ActivityPub instance      |
| Pocket-ID     | `id.doofnet.uk`                | OIDC provider                         |
| OAuth2 Proxy  | (middleware)                   | SSO gateway for internal services     |
| Rustical      | `calendar.svc.doofnet.uk`      | CalDAV server                         |
| Scanservjs    | `scanner.svc.doofnet.uk`       | Web-based scanner interface           |
| Hexgen        | `hexgen.doofnet.uk`            | Hex map generator                     |
| Globaltalk    | (internal)                     | GlobalTalk scraper (AppleTalk trends) |

### Media stack

| Service     | Purpose                                           |
| ----------- | ------------------------------------------------- |
| Sonarr      | TV series management                              |
| Radarr      | Movie management                                  |
| Lidarr      | Music management                                  |
| Prowlarr    | Indexer management                                |
| SABnzbd     | Usenet downloader                                 |
| IPlayarr    | BBC iPlayer integration                           |
| Calibre-web | E-book library                                    |
| Jellyfin    | Streaming (with hardware transcode via Coral TPU) |

## Networking

| Property   | Value                     |
| ---------- | ------------------------- |
| IPv4       | 10.101.3.20/16            |
| IPv6       | 2001:8b0:bd9:101::20/64   |
| ULA        | fddd:d00f:dab0:101::20/64 |
| DNS suffix | svc.doofnet.uk            |

## Database

PostgreSQL runs natively with databases for Mastodon, Gitea, Paperless, and other
services. The authentication is opened to the private VLAN so other infrastructure hosts
can connect.

## Service summary

| Service    | Package       | Purpose                             |
| ---------- | ------------- | ----------------------------------- |
| podman     | podman        | Container runtime                   |
| traefik    | traefik       | Reverse proxy (internal + external) |
| postgresql | postgresql    | Relational database                 |
| alloy      | grafana-alloy | Metrics and log shipping            |
