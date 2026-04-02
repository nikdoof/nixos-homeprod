
output "ns_ips" {
  description = "Public IPs of the DNS servers"
  value       = [aws_eip.ns_03.public_ip, aws_eip.ns_04.public_ip]
}
