variable "project_name" {
  description = "Project name"
  default     = "microservices"
}

variable "environment" {
  description = "Environment (e.g., dev, staging, prod)"
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "availability_zone" {
  description = "AWS availability zone"
  default     = "ap-south-1a"
}

variable "bundle_id" {
  description = "Instance bundle for master"
  default     = "medium_2_0" # 2 vCPU, 4GB RAM
}

variable "worker_bundle_id" {
  description = "Instance bundle for worker"
  default     = "small_2_0" # 2 vCPU, 2GB RAM
}

variable "ssh_key_name" {
  description = "Existing Lightsail SSH key pair name"
}

variable "private_key_path" {
  description = "Path to private SSH key"
}

variable "worker_count" {
  description = "Number of worker nodes"
  default     = 2
}
