# web-01: Web Hosting

web-01 is a NixOS microVM (CID 14) on hyp-01, running on VLAN 106. It serves static
websites for multiple domains via Nginx.

## Network

| Property     | Value                          |
|--------------|--------------------------------|
| Platform     | microVM, CID 14, VLAN 106      |
| IPv4         | 217.169.25.10/29               |
| IPv6         | 2001:8b0:bd9:106::2/64        |
| Gateway      | 217.169.25.9 (gw hosted VLAN)  |

Open ports: **80** (redirect), **443** (HTTPS).

## Hosted domains

All domains serve static content from `/persist/sites/<domain>/`:

| Domain                           | Notes                              |
|----------------------------------|------------------------------------|
| `web-01.doofnet.uk`              | Redirects to doofnet.uk            |
| `2315media.com`                  |                                    |
| `bluecalx.co.uk`                 |                                    |
| `dimension.sh`                   |                                    |
| `doofnet.uk`                     | Primary personal site              |
| `hereforthis.uk`                 |                                    |
| `incognitus.net`                 |                                    |
| `intellectops.com`               |                                    |
| `nikdoof.com`                    |                                    |
| `oojamaflip.wtf`                 |                                    |
| `parkpioneer.com`                |                                    |
| `parkpioneer.review.2315media.com` |                                  |

### Redirects

| Domain                          | Redirects to           |
|---------------------------------|------------------------|
| `thatgirl.co.uk`                | `oojamaflip.wtf`       |
| `alanthetravellingalpaca.com`   | `oojamaflip.wtf`       |
| `joslittlecorner.co.uk`         | `oojamaflip.wtf`       |
| `joslittlecorner.com`           | `oojamaflip.wtf`       |
| `nikdoof.id`                    | `nikdoof.com`          |
| `andrewwilliams.net`            | `nikdoof.com`          |
| `andrew.williams.id`            | `nikdoof.com`          |

## Deployment

Site content is deployed via `rsync` over SSH by the `deploy` system user. The user's
`ForceCommand` is restricted to `rrsync /persist/sites`, preventing access outside the
sites directory.

## Security

- All sites enforce HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy
- fail2ban is enabled for SSH and web-based attacks
- Nginx server tokens are disabled

## Service summary

| Service              | Package                   | Purpose                                    |
|----------------------|---------------------------|--------------------------------------------|
| nginx                | nginx                     | Static web server + ACME TLS termination   |
| prometheus-nginx-exporter | prometheus-nginx-exporter | Nginx metrics                          |
| alloy                | grafana-alloy             | Log shipping (nginx access/error logs)     |
