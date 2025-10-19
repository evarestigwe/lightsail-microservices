##############################
# General Configuration
##############################

variable "project_name" {
  description = "Project name used as prefix for resources"
  type        = string
  default     = "lightsail-microservices"
}

variable "aws_region" {
  description = "AWS region for Lightsail deployment"
  type        = string
  default     = "ap-southeast-1"
}

variable "domain_name" {
  description = "Root domain name for ingress/TLS"
  type        = string
  default     = "example.com"
}

variable "instance_blueprint_id" {
  description = "Lightsail OS image ID"
  type        = string
  default     = "ubuntu_22_04"
}

variable "instance_bundle_id" {
  description = "Lightsail instance size"
  type        = string
  default     = "medium_2_0" # 2 vCPU, 4 GB RAM
}

variable "key_pair_name" {
  description = "Existing Lightsail key pair name for SSH access"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to your public SSH key for instance access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

##############################
# Cluster Configuration
##############################

variable "num_worker_nodes" {
  description = "Number of worker nodes to create initially"
  type        = number
  default     = 2
}

variable "environment_labels" {
  description = "Labels for each worker node environment"
  type        = map(string)
  default = {
    dev     = "worker-dev"
    staging = "worker-staging"
    prod    = "worker-prod"
  }
}

##############################
# Autoscaling Configuration
##############################

variable "enable_autoscaling" {
  description = "Enable or disable autoscaling Lambda"
  type        = bool
  default     = true
}

variable "cpu_threshold_scale_up" {
  description = "CPU threshold for scaling up"
  type        = number
  default     = 70
}

variable "memory_threshold_scale_up" {
  description = "Memory threshold for scaling up"
  type        = number
  default     = 70
}

variable "cpu_threshold_scale_down" {
  description = "CPU threshold for scaling down"
  type        = number
  default     = 30
}

variable "memory_threshold_scale_down" {
  description = "Memory threshold for scaling down"
  type        = number
  default     = 30
}

variable "scale_down_cooldown_minutes" {
  description = "How long to wait before scaling down (minutes)"
  type        = number
  default     = 15
}

##############################
# GitHub Integration
##############################

variable "github_repo" {
  description = "GitHub repository name for syncing secrets"
  type        = string
  default     = "lightsail-microservices"
}

variable "github_owner" {
  description = "GitHub username or org name"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token (with repo + actions:write)"
  type        = string
  sensitive   = true
}

##############################
# Misc
##############################

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}
