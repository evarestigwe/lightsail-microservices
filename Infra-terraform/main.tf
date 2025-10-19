###########################################
# Provider and Backend Configuration
###########################################
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.30"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

###########################################
# Key Pair
###########################################

resource "aws_lightsail_key_pair" "default" {
  name       = "${var.project_name}-key"
  public_key = file(var.ssh_public_key_path)
}

###########################################
# Lightsail Master Node
###########################################

resource "aws_lightsail_instance" "master" {
  name              = "${var.project_name}-master"
  availability_zone = "${var.aws_region}a"
  blueprint_id      = var.instance_blueprint_id
  bundle_id         = var.instance_bundle_id
  key_pair_name     = aws_lightsail_key_pair.default.name

  tags = merge(var.tags, {
    Role = "master"
  })

  provisioner "file" {
    source      = "${path.module}/scripts/install_k3s.sh"
    destination = "/home/ubuntu/install_k3s.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/install_k3s.sh",
      "sudo /home/ubuntu/install_k3s.sh master"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip_address
    }
  }
}

###########################################
# Lightsail Worker Nodes
###########################################

resource "aws_lightsail_instance" "worker_nodes" {
  count             = var.num_worker_nodes
  name              = "${var.project_name}-worker-${count.index + 1}"
  availability_zone = "${var.aws_region}a"
  blueprint_id      = var.instance_blueprint_id
  bundle_id         = var.instance_bundle_id
  key_pair_name     = aws_lightsail_key_pair.default.name

  tags = merge(var.tags, {
    Role        = "worker"
    Environment = element(keys(var.environment_labels), count.index % length(keys(var.environment_labels)))
  })

  provisioner "file" {
    source      = "${path.module}/scripts/install_k3s.sh"
    destination = "/home/ubuntu/install_k3s.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/install_k3s.sh",
      "sudo /home/ubuntu/install_k3s.sh worker ${aws_lightsail_instance.master.private_ip_address}"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip_address
    }
  }
}

###########################################
# Lightsail Load Balancer (HTTPS Termination)
###########################################

resource "aws_lightsail_lb" "main" {
  name              = "${var.project_name}-lb"
  health_check_path = "/"
  instance_port     = 32001
  tags              = merge(var.tags, { Role = "load-balancer" })
}

resource "aws_lightsail_lb_certificate" "tls" {
  name        = "${var.project_name}-cert"
  lb_name     = aws_lightsail_lb.main.name
  domain_name = var.domain_name
}

resource "aws_lightsail_lb_attachment" "master_backend" {
  lb_name       = aws_lightsail_lb.main.name
  instance_name = aws_lightsail_instance.master.name
}

###########################################
# Autoscaling Lambda (Scale Up & Down)
###########################################

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_exec" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "lightsail_autoscaler" {
  filename         = "${path.module}/scripts/lambda_autoscale.py.zip"
  function_name    = "${var.project_name}-autoscaler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_autoscale.lambda_handler"
  runtime          = "python3.9"
  timeout          = 60
  source_code_hash = filebase64sha256("${path.module}/scripts/lambda_autoscale.py.zip")

  environment {
    variables = {
      CPU_UP_THRESHOLD    = tostring(var.cpu_threshold_scale_up)
      MEM_UP_THRESHOLD    = tostring(var.memory_threshold_scale_up)
      CPU_DOWN_THRESHOLD  = tostring(var.cpu_threshold_scale_down)
      MEM_DOWN_THRESHOLD  = tostring(var.memory_threshold_scale_down)
      COOLDOWN_MINUTES    = tostring(var.scale_down_cooldown_minutes)
      PROJECT_NAME        = var.project_name
    }
  }
}

resource "aws_cloudwatch_event_rule" "autoscale_rule" {
  name                = "${var.project_name}-autoscale-schedule"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "autoscale_target" {
  rule      = aws_cloudwatch_event_rule.autoscale_rule.name
  target_id = "autoscaler"
  arn       = aws_lambda_function.lightsail_autoscaler.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lightsail_autoscaler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.autoscale_rule.arn
}

###########################################
# GitHub Secrets Sync (Kubeconfig + LB DNS)
###########################################

resource "github_actions_secret" "kubeconfig_secret" {
  repository      = var.github_repo
  secret_name     = "KUBECONFIG_BASE64"
  plaintext_value = base64encode(file("${path.module}/generated/kubeconfig"))
}

resource "github_actions_secret" "loadbalancer_dns_secret" {
  repository      = var.github_repo
  secret_name     = "LOADBALANCER_DNS"
  plaintext_value = aws_lightsail_lb.main.dns_name
}

###########################################
# Outputs
###########################################

output "master_ip" {
  description = "Master node public IP"
  value       = aws_lightsail_instance.master.public_ip_address
}

output "worker_ips" {
  description = "Worker node public IPs"
  value       = [for w in aws_lightsail_instance.worker_nodes : w.public_ip_address]
}

output "load_balancer_dns" {
  description = "Lightsail LB DNS name"
  value       = aws_lightsail_lb.main.dns_name
}

output "kubeconfig_secret_pushed" {
  description = "GitHub secret created for kubeconfig"
  value       = "✅ Synced to GitHub Actions"
}
