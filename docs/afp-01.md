# afp-01: Apple File Sharing

afp-01 is a NixOS microVM (CID 11) on hyp-01, running on VLAN 101. It provides AFP file
sharing via Netatalk and AppleTalk printing via papd for legacy Mac clients.

## Network

| Property | Value                       |
| -------- | --------------------------- |
| Platform | microVM, CID 11, VLAN 101   |
| IPv4     | 10.101.3.30/16              |
| IPv6     | 2001:8b0:bd9:101::3:30/64   |
| ULA      | fddd:d00f:dab0:101::3:30/64 |

## Netatalk (AFP file sharing)

Netatalk 4.4.1 serves AFP volumes to legacy Mac clients over AppleTalk and TCP:

| Volume           | Path                                | Access                              |
| ---------------- | ----------------------------------- | ----------------------------------- |
| Software Archive | `/persist/netatalk/shares/archive`  | Read-only (nobody), write (nikdoof) |
| Dropbox          | `/persist/netatalk/shares/dropbox`  | Read-write (anyone)                 |
| Transfer         | `/persist/netatalk/shares/transfer` | nikdoof only                        |
| Data             | `/persist/netatalk/shares/data`     | Read-only (nobody), write (nikdoof) |

### AppleTalk daemon (`atalkd`)

The `atalkd` service provides AppleTalk Phase 2 routing, required by Netatalk for legacy
protocol support (DDP, PAP, etc.).

### PAP printing (`papd`)

The `papd` service enables AppleTalk printing to an HP LaserJet 200 M251n. CUPS is also
enabled for IPP printing.

## GlobalTalk scraper

The GlobalTalk scraper (`services.globaltalk.scrape`) fetches AppleTalk network trends
and writes results to `/persist/netatalk/shares/data/globaltalk.json`, making them
available on the Data volume. Metrics are enabled for Prometheus collection.

## Dropbox notify

A notification service watches the Dropbox volume and posts to the Mastodon instance
(`social.doofnet.uk`) when new files are added. Currently runs in dry-run mode.

## Persistence

Netatalk shares and CNID databases are stored under `/persist/netatalk/`.

## Service summary

| Service            | Package                  | Purpose                               |
| ------------------ | ------------------------ | ------------------------------------- |
| netatalk           | netatalk 4.4.1           | AFP file server                       |
| atalkd             | netatalk                 | AppleTalk Phase 2 routing             |
| papd               | netatalk                 | AppleTalk printing                    |
| avahi              | avahi                    | mDNS/Bonjour service discovery        |
| globaltalk-scraper | globaltalk-scraper flake | AppleTalk trend scraper               |
| cupd               | cups                     | IPP printing                          |
| dropbox-notify     | (custom)                 | Watch dropbox and notify via Mastodon |
| alloy              | grafana-alloy            | Metrics and log shipping              |
