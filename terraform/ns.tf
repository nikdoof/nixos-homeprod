locals {
  tags = {
    Role = "ns"
  }
}

# NixOS AMIs
# https://nixos.github.io/amis/
#
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

# IAM and instance roles
#
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    sid     = "EC2"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ns" {
  name = "ns-role"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ns_ssm" {
  role       = aws_iam_role.ns.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ns" {
  name = "ns-instance-profile"
  role = aws_iam_role.ns.name
}


# SGs
#
resource "aws_security_group" "ns_03" {
  provider    = aws.eu_west_1
  name        = "ns-03"
  description = "ns-03 nameserver"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_access_ips
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
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_access_ips
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

# SSH keypairs
#
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

# Instances
#
resource "aws_instance" "ns_03" {
  provider               = aws.eu_west_1
  ami                    = data.aws_ami.nixos_eu_west_1.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.nikdoof_eu_west_1.key_name
  iam_instance_profile   = aws_iam_instance_profile.ns.name
  vpc_security_group_ids = [aws_security_group.ns_03.id]

  tags = merge(local.tags, { Name = "ns-03" })
}

resource "aws_instance" "ns_04" {
  provider               = aws.eu_west_2
  ami                    = data.aws_ami.nixos_eu_west_2.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.nikdoof_eu_west_2.key_name
  iam_instance_profile   = aws_iam_instance_profile.ns.name
  vpc_security_group_ids = [aws_security_group.ns_04.id]

  tags = merge(local.tags, { Name = "ns-04" })
}

resource "aws_eip" "ns_03" {
  provider = aws.eu_west_1
  instance = aws_instance.ns_03.id
  domain   = "vpc"

  tags = merge(local.tags, { Name = "ns-03-eip" })
}

resource "aws_eip" "ns_04" {
  provider = aws.eu_west_2
  instance = aws_instance.ns_04.id
  domain   = "vpc"

  tags = merge(local.tags, { Name = "ns-04-eip" })
}

# DNS entries
#
resource "digitalocean_record" "ns_03" {
  domain = "doofnet.uk"
  type   = "A"
  name   = "ns-03"
  value  = aws_eip.ns_03.public_ip
  ttl    = 3600
}

resource "digitalocean_record" "ns_04" {
  domain = "doofnet.uk"
  type   = "A"
  name   = "ns-04"
  value  = aws_eip.ns_04.public_ip
  ttl    = 3600
}
