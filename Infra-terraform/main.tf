terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "github" {
  token = var.github_token
}

# --------------------------
# Lightsail Key Pair
# --------------------------
resource "aws_lightsail_key_pair" "main" {
  name       = "lightsail-key"
  public_key = file(var.ssh_public_key_path)
}

# --------------------------
# Lightsail Master Instance with injected SSH key
# --------------------------
resource "aws_lightsail_instance" "master" {
  name              = "k3s-master"
  availability_zone = var.aws_az
  blueprint_id      = "ubuntu_22_04"
  bundle_id         = "nano_3_0"

  user_data = <<-EOT
              #!/bin/bash
              mkdir -p /home/ubuntu/.ssh
              echo "${file(var.ssh_public_key_path)}" >> /home/ubuntu/.ssh/authorized_keys
              chown -R ubuntu:ubuntu /home/ubuntu/.ssh
              chmod 700 /home/ubuntu/.ssh
              chmod 600 /home/ubuntu/.ssh/authorized_keys
              EOT
}

# --------------------------
# Package Lambda automatically
# --------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/scripts/lambda_autoscale.py"
  output_path = "${path.module}/scripts/lambda_autoscale.py.zip"
}

# --------------------------
# Lambda Role
# --------------------------
resource "aws_iam_role" "lambda_exec_role" {
  name = "lightsail-autoscaler-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --------------------------
# Lambda Function
# --------------------------
resource "aws_lambda_function" "lightsail_autoscaler" {
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = "lightsail-autoscaler"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_autoscale.lambda_handler"
  runtime          = "python3.10"
  timeout          = 60
}

# --------------------------
# Fetch kubeconfig from master
# --------------------------
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [aws_lightsail_instance.master]

  provisioner "remote-exec" {
    inline = [
      "sudo cat /etc/rancher/k3s/k3s.yaml > /home/ubuntu/kubeconfig_temp"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = aws_lightsail_instance.master.public_ip_address
    }
  }
}

# --------------------------
# Local kubeconfig file (placeholder)
# --------------------------
resource "local_file" "kubeconfig" {
  depends_on = [null_resource.fetch_kubeconfig]
  filename   = "${path.module}/generated/kubeconfig"
  content    = <<EOT
# Placeholder kubeconfig.
# In practice, fetch dynamically from master (via SCP or Terraform external script).
EOT
}

# --------------------------
# Sync kubeconfig to GitHub Actions
# --------------------------
resource "github_actions_secret" "kubeconfig_secret" {
  repository      = var.github_repo
  secret_name     = "KUBECONFIG"
  # Use the content attribute instead of reading a file
  plaintext_value = base64encode(local_file.kubeconfig.content)
}

# --------------------------
# Outputs
# --------------------------
output "master_public_ip" {
  value = aws_lightsail_instance.master.public_ip_address
}

output "kubeconfig_content" {
  value = local_file.kubeconfig.content
}

output "lambda_function_name" {
  value = aws_lambda_function.lightsail_autoscaler.function_name
}
