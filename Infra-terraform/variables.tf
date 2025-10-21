variable "aws_region" {
  description = "The AWS region to deploy resources in (e.g., us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "aws_az" {
  description = "The AWS availability zone for the Lightsail instance (e.g., us-east-1a)"
  type        = string
  default     = "us-east-1a"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key file (e.g., ~/.ssh/id_rsa.pub)"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file (e.g., ~/.ssh/id_rsa)"
  type        = string
}

variable "github_repo" {
  description = "The name of the GitHub repository (e.g., owner/repo-name)"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token for managing Actions secrets"
  type        = string
  sensitive   = true
}

variable "my_ip" {
  description = "Your public IP address in CIDR format (e.g., 203.0.113.0/32) for SSH access"
  type        = string
  default     = "0.0.0.0/0"  # Open for testing; replace with your IP for security
}