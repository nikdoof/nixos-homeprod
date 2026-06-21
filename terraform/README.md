# Terraform

Manages the public-facing cloud infrastructure for doofnet.uk.

## Resources

- **AWS EC2** — `ns-03` (eu-west-1) and `ns-04` (eu-west-2): BIND secondary nameservers serving publicly-delegated reverse zones, fronted by Elastic IPs with rDNS.
- **DigitalOcean DNS** — A records for `ns-03` / `ns-04`, MX records for 3 domains (`doofnet.uk`, `nikdoof.com`, `nikdoof.id`), SPF, DMARC, and SRV records (`_imaps._tcp`, `_submission._tcp`).
- **GotoSocial CDN** — S3 bucket (eu-west-2) with public website hosting for GoToSocial media attachments, plus an IAM user with scoped credentials.
- **SMS Bot** — Lambda function (eu-west-2) serving Twilio SMS/call webhooks, managed via an external module.

## Usage

```bash
# Initialise (first time or after provider changes)
tofu init

# Review changes
tofu plan

# Apply
tofu apply

# Destroy
tofu destroy
```

## Variables

| Variable         | Description                        | Default                      |
| ---------------- | ---------------------------------- | ---------------------------- |
| `do_token`       | DigitalOcean API token (sensitive) | -                            |
| `regions`        | AWS deployment regions             | `["eu-west-1", "eu-west-2"]` |
| `instance_type`  | EC2 instance type                  | `t3a.micro`                  |
| `ssh_access_ips` | CIDRs allowed SSH access           | `["81.187.48.147/32"]`       |
| `ssh_key`        | SSH public key for EC2             | nikdoof's ed25519 key        |

## Secrets

The DigitalOcean API token (`do_token`) is stored in the `digitalOceanApiToken.age` agenix secret. Decrypt and export before running tofu:

```bash
export DO_TOKEN=$(agenix -e secrets/digitalOceanApiToken.age)
tofu plan -var="do_token=$DO_TOKEN"
```
