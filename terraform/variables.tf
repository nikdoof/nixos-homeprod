variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "regions" {
  description = "List of regions to deploy to"
  type        = list(string)
  default     = ["eu-west-1", "eu-west-2"]
}

variable "instance_type" {
  description = "Instance type to use for the DNS servers"
  type        = string
  default     = "t4g.nano"

}

variable "ssh_access_ips" {
  description = "List of CIDRs that can access the DNS servers via SSH"
  type        = list(string)
  default     = ["81.187.48.147/32"]
}

variable "ssh_key" {
  description = "SSH key to apply to the instances"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHWO2qwHaPaQs46na4Aa6gMkw5QqRHUMGQphtgAcDJOw"
}
