##############################
# Core Infrastructure Outputs
##############################

output "master_public_ip" {
  description = "Public IP address of the K3s master node"
  value       = aws_lightsail_instance.master.public_ip_address
}

output "worker_public_ips" {
  description = "List of public IP addresses of worker nodes"
  value       = [for w in aws_lightsail_instance.worker_nodes : w.public_ip_address]
}

output "load_balancer_dns" {
  description = "Lightsail load balancer public DNS name"
  value       = aws_lightsail_lb.main.dns_name
}

output "ssh_command_master" {
  description = "SSH command to connect to master node"
  value       = "ssh ubuntu@${aws_lightsail_instance.master.public_ip_address}"
}

##############################
# K3s + Helm Configuration
##############################

output "kubeconfig" {
  description = "Base64-encoded kubeconfig for GitHub Actions"
  value       = base64encode(file("${path.module}/generated/kubeconfig"))
  sensitive   = true
}

output "cluster_info" {
  description = "Summary of cluster info (IPs, roles, environments)"
  value = {
    master_ip  = aws_lightsail_instance.master.public_ip_address
    worker_ips = [for w in aws_lightsail_instance.worker_nodes : w.public_ip_address]
    environments = var.environment_labels
  }
}

##############################
# Autoscaling Outputs
##############################

output "autoscaling_enabled" {
  description = "True if Lambda autoscaling is enabled"
  value       = var.enable_autoscaling
}

output "autoscaling_lambda_function_name" {
  description = "Name of the Lambda function performing autoscaling"
  value       = aws_lambda_function.lightsail_autoscaler.function_name
}

output "autoscaling_thresholds" {
  description = "CPU and memory thresholds for scaling up/down"
  value = {
    scale_up_cpu    = var.cpu_threshold_scale_up
    scale_up_memory = var.memory_threshold_scale_up
    scale_down_cpu  = var.cpu_threshold_scale_down
    scale_down_memory = var.memory_threshold_scale_down
  }
}

##############################
# GitHub Secrets Integration
##############################

output "github_repo" {
  description = "GitHub repository linked for CI/CD secret sync"
  value       = var.github_repo
}

output "github_secrets_synced" {
  description = "Status of secrets sync to GitHub"
  value       = "✅ kubeconfig + load balancer DNS pushed to GitHub Actions secrets"
}

##############################
# Ingress Information
##############################

output "ingress_endpoints" {
  description = "Environment-specific ingress endpoints"
  value = {
    dev     = "https://dev.${var.domain_name}"
    staging = "https://staging.${var.domain_name}"
    prod    = "https://api.${var.domain_name}"
  }
}
