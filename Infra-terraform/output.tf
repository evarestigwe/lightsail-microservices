output "master_public_ip" {
  value = aws_lightsail_static_ip.master_ip.ip_address
}

output "worker_public_ips" {
  value = join(",", aws_lightsail_instance.worker[*].public_ip_address)
}

output "ssh_master" {
  value = "ssh -i ${var.private_key_path} ubuntu@${aws_lightsail_static_ip.master_ip.ip_address}"
}
