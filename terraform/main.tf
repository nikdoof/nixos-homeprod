terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

variable "public_ip" {
  description = "Public IP CIDR for SSH access"
  type        = string
  default     = "81.187.48.147/32"
}

variable "ssh_key" {
  description = "SSH key to apply to the instances"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHWO2qwHaPaQs46na4Aa6gMkw5QqRHUMGQphtgAcDJOw"
}

# ── Providers ────────────────────────────────────────────────────────────────

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

provider "aws" {
  alias  = "eu_west_2"
  region = "eu-west-2"
}

# ── NixOS AMIs (aarch64 for t4g) ─────────────────────────────────────────────

data "aws_ami" "nixos_eu_west_1" {
  provider    = aws.eu_west_1
  most_recent = true
  owners      = ["427812963091"]

  filter {
    name   = "name"
    values = ["nixos/25.11*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

data "aws_ami" "nixos_eu_west_2" {
  provider    = aws.eu_west_2
  most_recent = true
  owners      = ["427812963091"]

  filter {
    name   = "name"
    values = ["nixos/25.11*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

# ── IAM (global) ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "ns" {
  name = "ns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ns_ssm" {
  role       = aws_iam_role.ns.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ns" {
  name = "ns-instance-profile"
  role = aws_iam_role.ns.name
}

# ── Security groups ───────────────────────────────────────────────────────────

resource "aws_security_group" "ns_03" {
  provider    = aws.eu_west_1
  name        = "ns-03"
  description = "ns-03 nameserver"

  ingress {
    description = "SSH from home"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.public_ip]
  }

  ingress {
    description      = "DNS TCP"
    from_port        = 53
    to_port          = 53
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "DNS UDP"
    from_port        = 53
    to_port          = 53
    protocol         = "udp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "ns_04" {
  provider    = aws.eu_west_2
  name        = "ns-04"
  description = "ns-04 nameserver"

  ingress {
    description = "SSH from home"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.public_ip]
  }

  ingress {
    description      = "DNS TCP"
    from_port        = 53
    to_port          = 53
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "DNS UDP"
    from_port        = 53
    to_port          = 53
    protocol         = "udp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# ── SSH key pairs (region-scoped) ────────────────────────────────────────────

resource "aws_key_pair" "nikdoof_eu_west_1" {
  provider   = aws.eu_west_1
  key_name   = "nikdoof"
  public_key = var.ssh_key
}

resource "aws_key_pair" "nikdoof_eu_west_2" {
  provider   = aws.eu_west_2
  key_name   = "nikdoof"
  public_key = var.ssh_key
}

# ── Instances ─────────────────────────────────────────────────────────────────

resource "aws_instance" "ns_03" {
  provider               = aws.eu_west_1
  ami                    = data.aws_ami.nixos_eu_west_1.id
  instance_type          = "t4g.nano"
  key_name               = aws_key_pair.nikdoof_eu_west_1.key_name
  iam_instance_profile   = aws_iam_instance_profile.ns.name
  vpc_security_group_ids = [aws_security_group.ns_03.id]

  tags = { Name = "ns-03" }
}

resource "aws_instance" "ns_04" {
  provider               = aws.eu_west_2
  ami                    = data.aws_ami.nixos_eu_west_2.id
  instance_type          = "t4g.nano"
  key_name               = aws_key_pair.nikdoof_eu_west_2.key_name
  iam_instance_profile   = aws_iam_instance_profile.ns.name
  vpc_security_group_ids = [aws_security_group.ns_04.id]

  tags = { Name = "ns-04" }
}

# ── Elastic IPs ───────────────────────────────────────────────────────────────

resource "aws_eip" "ns_03" {
  provider = aws.eu_west_1
  instance = aws_instance.ns_03.id
  domain   = "vpc"

  tags = { Name = "ns-03" }
}

resource "aws_eip" "ns_04" {
  provider = aws.eu_west_2
  instance = aws_instance.ns_04.id
  domain   = "vpc"

  tags = { Name = "ns-04" }
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "ns_03_public_ip" {
  value = aws_eip.ns_03.public_ip
}

output "ns_04_public_ip" {
  value = aws_eip.ns_04.public_ip
}
