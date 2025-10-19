variable "env" {
  description = "Environment: dev, staging, prod"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for Lightsail"
  type        = string
  default     = "ap-southeast-1"
}

variable "aws_az" {
  description = "AWS Availability Zone"
  type        = string
  default     = "ap-southeast-1a"
}

variable "lightsail_bundle" {
  description = "Lightsail bundle ID (ensure it exists in the region)"
  type        = string
  default     = "nano_1_0" # replace with a valid bundle from `aws lightsail get-bundles`
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "github_token" {
  description = "GitHub Personal Access Token"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (user/repo)"
  type        = string
}
