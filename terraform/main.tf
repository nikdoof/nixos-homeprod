terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.39"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.84.0"
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

provider "digitalocean" {
  token = var.do_token
}
