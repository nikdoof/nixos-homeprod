terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.39"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.100.0"
    }
  }
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

provider "aws" {
  alias  = "eu_west_2"
  region = "eu-west-2"
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

provider "digitalocean" {
  token = var.do_token
}
