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
# Lightsail Master Instance with injected SSH key and K3s installation
# --------------------------
resource "aws_lightsail_instance" "master" {
  name              = "k3s-master"
  availability_zone = var.aws_az
  blueprint_id      = "ubuntu_22_04"
  bundle_id         = "nano_3_0"

  user_data = <<-EOT
              #!/bin/bash
              # Set up SSH
              mkdir -p /home/ubuntu/.ssh
              echo "${file(var.ssh_public_key_path)}" >> /home/ubuntu/.ssh/authorized_keys
              chown -R ubuntu:ubuntu /home/ubuntu/.ssh
              chmod 700 /home/ubuntu/.ssh
              chmod 600 /home/ubuntu/.ssh/authorized_keys

              # Install K3s (single-node master)
              curl -sfL https://get.k3s.io | sh -s - server --write-kubeconfig-mode 644
              # Make kubeconfig accessible to ubuntu user
              sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/kubeconfig_temp
              sudo chown ubuntu:ubuntu /home/ubuntu/kubeconfig_temp
              EOT
}

# --------------------------
# Open SSH port (22) on the instance
# --------------------------
resource "aws_lightsail_instance_public_ports" "master" {
  instance_name = aws_lightsail_instance.master.name

  port_info {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidrs     = [var.my_ip]  # Restrict to your IP for security; use "0.0.0.0/0" for testing
  }
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
# Wait for instance to be ready (boot + user_data execution)
# --------------------------
resource "null_resource" "wait_for_instance" {
  depends_on = [aws_lightsail_instance.master, aws_lightsail_instance_public_ports.master]

  provisioner "local-exec" {
    command = "sleep 60"  # Wait 60 seconds for boot and user_data
  }
}

# --------------------------
# Prepare kubeconfig on remote (and fetch it locally via SCP)
# --------------------------
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [null_resource.wait_for_instance]

  provisioner "remote-exec" {
    inline = [
      # Ensure kubeconfig is prepared (user_data should have done this, but verify)
      "sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/kubeconfig_temp || true",
      "sudo chown ubuntu:ubuntu /home/ubuntu/kubeconfig_temp",
      "chmod 600 /home/ubuntu/kubeconfig_temp"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = aws_lightsail_instance.master.public_ip_address
      timeout     = "5m"  # Increased timeout for safety
    }
  }

  # Fetch the kubeconfig locally via SCP
  provisioner "local-exec" {
    command = "scp -i ${var.ssh_private_key_path} ubuntu@${aws_lightsail_instance.master.public_ip_address}:/home/ubuntu/kubeconfig_temp ${path.module}/generated/kubeconfig"
  }
}

# --------------------------
# Local kubeconfig file (now dynamic)
# --------------------------
resource "local_file" "kubeconfig" {
  depends_on = [null_resource.fetch_kubeconfig]
  filename   = "${path.module}/generated/kubeconfig"
  # Content will be written by the SCP in fetch_kubeconfig; this ensures the file exists
  content    = fileexists("${path.module}/generated/kubeconfig") ? file("${path.module}/generated/kubeconfig") : "# Placeholder - fetched via SCP"
}

# --------------------------
# Sync kubeconfig to GitHub Actions
# --------------------------
resource "github_actions_secret" "kubeconfig_secret" {
  repository      = var.github_repo
  secret_name     = "KUBECONFIG"
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