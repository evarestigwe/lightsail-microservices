| Secret                     | Description                                               |
| -------------------------- | --------------------------------------------------------- |
| `DOCKERHUB_USERNAME`       | Docker Hub username                                       |
| `DOCKERHUB_TOKEN`          | Docker Hub access token                                   |
| `KUBECONFIG_BASE64`        | Base64-encoded kubeconfig (Terraform output)              |
| `LOAD_BALANCER_DNS`        | Lightsail load balancer DNS name                          |
| `TEAMS_WEBHOOK_URL`        | Microsoft Teams incoming webhook                          |
| `SERVICES_HOSTS_<SERVICE>` | (Optional) service-specific hostnames for smoke test URLs |



.🏗️ Microservices Deployment on AWS Lightsail with Terraform, Helm & GitHub Actions
A complete containerized microservices deployment platform built on AWS Lightsail, orchestrated via K3s (lightweight Kubernetes), automated with Terraform and GitHub Actions, secured with managed HTTPS, and monitored with autoscaling.

🚀 Overview
This repository provides a ready-to-deploy, scalable, and production-ready microservices architecture consisting of:

5 Microservices:

🧾 payment-service

🔐 user-auth-service

📦 order-service

🛒 cart-service

🏷️ product-service

Automated Infrastructure:

AWS Lightsail Instances provisioned via Terraform

Master node + Worker nodes (Dev/Staging/Prod)

Lightsail Load Balancer with Managed TLS (Let’s Encrypt)

k3s (Kubernetes) cluster + Helm setup

Automated CI/CD:

GitHub Actions pipeline:

Build, Test, Lint

Static code analysis (SonarQube)

Security scan (Trivy)

Deploy via Helm (atomic rollback)

Canary deployments

Teams notifications on rollback

Intelligent Autoscaling:

Lambda-based scale-up/down of Lightsail worker nodes based on CPU/Memory thresholds

Dynamic GitHub Secret sync for kubeconfig and IPs

🧩 Repository Structure
bash
Copy code
.
├── .github/
│   └── workflows/
│       └── microservice-deploy.yml          # CI/CD Workflow (GitHub Actions)
├── charts/
│   ├── microservices/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── templates/
│   │   │   ├── _helpers.tpl
│   │   │   ├── NOTES.txt
│   │   │   ├── ingress.yaml
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── hpa.yaml
│   │   │   ├── configmap.yaml
│   │   │   └── secrets.yaml
│   │   ├── charts/
│   │   │   ├── payment-service/
│   │   │   ├── user-auth-service/
│   │   │   ├── order-service/
│   │   │   ├── product-service/
│   │   │   └── cart-service/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── autoscaling.tf
│   ├── provider.tf
│   └── lambda_autoscaler/
│       └── lambda.py
├── payment-service/
├── user-auth-service/
├── order-service/
├── product-service/
├── cart-service/
├── .gitignore
├── .dockerignore
├── .terraformignore
├── .trivyignore
├── .helmignore
└── README.md
⚙️ Prerequisites
AWS Account (Lightsail + Lambda + IAM)

GitHub Repository with Actions Enabled

Docker Hub or AWS ECR account for image hosting

Terraform ≥ 1.6

Helm ≥ 3.12

kubectl

AWS CLI configured with credentials

SonarQube & Trivy CLI (for local scans)

🧱 Infrastructure Setup (Terraform)
1️⃣ Configure Variables
Edit terraform/variables.tf and set your values:

hcl
Copy code
aws_region       = "ap-southeast-1"
project_name     = "lightsail-microservices"
domain_name      = "example.com"
enable_autoscaling = true
cpu_threshold    = 70
memory_threshold = 70
2️⃣ Deploy Infrastructure
bash
Copy code
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
Terraform will:

Provision master + worker Lightsail instances

Install k3s + Helm

Configure Lightsail load balancer with HTTPS

Register Let’s Encrypt certificates

Push kubeconfig & IPs to GitHub Secrets automatically

🐳 CI/CD Workflow (GitHub Actions)
The workflow (.github/workflows/microservice-deploy.yml) automates the following:

Stage	Description
🧪 Test	Runs unit tests before builds
🧹 Lint & SAST	Static code analysis via SonarQube
🧱 Build	Builds Docker image for the changed microservice only
🔍 Scan	Security scan with Trivy
🚀 Deploy	Helm deploys to dev/staging/prod environments
⚡ Canary Rollout	Gradual 10%→50%→100% rollout
🔁 Rollback	Auto rollback if deployment fails
💬 Teams Notification	Notifies dev team on rollback/failure

Trigger Rules
Event	Environment
Push or Closed PR → dev	Deploys to Dev
Merge dev → staging	Deploys to Staging
Merge staging → main	Deploys to Production

🌐 Helm Deployment
Each microservice is a subchart under charts/microservices/charts/.
Values are overridden per environment via:

values-dev.yaml

values-staging.yaml

values-prod.yaml

Example:
bash
Copy code
helm upgrade --install payment charts/microservices/charts/payment-service \
  --namespace dev \
  --values charts/microservices/values-dev.yaml \
  --atomic --timeout 5m
🔄 Autoscaling
A Lambda function (deployed by Terraform) monitors metrics:

Condition	Action
CPU/Memory > 70% for 5 min	Scale up worker nodes
CPU/Memory < 30% for 15 min	Scale down unused workers

All updates sync automatically with GitHub Secrets so CI/CD always deploys to the correct nodes.

🧩 Local Development
Node.js Microservices
bash
Copy code
cd payment-service
npm install
npm run dev
Go Microservices
bash
Copy code
cd order-service
go mod tidy
go run main.go
🧰 Environment Variables
Each service should include an .env.example like:

bash
Copy code
PORT=8080
DATABASE_URL=postgres://user:pass@db:5432/app
JWT_SECRET=mysecret
REDIS_URL=redis://cache:6379
These map to Kubernetes secrets via Helm automatically.

📜 Rollback & History
Rollback to the previous version with:

bash
Copy code
helm rollback payment 1 -n dev
Check deployment history:

bash
Copy code
helm history payment -n dev
🔒 Security & Compliance
Trivy: Scans images for CVEs

SonarQube: Detects code smells and vulnerabilities

Atomic Helm Deployments: Ensures rollback on failure

Secrets Management: via GitHub Secrets + K8s Secrets

📣 Notifications (Microsoft Teams)
On deployment rollback or failure, the workflow sends a Teams notification using a Webhook defined in:

yaml
Copy code
secrets.MS_TEAMS_WEBHOOK_URL
You can customize message templates in .github/actions/teams_notify.yml.

🧠 Troubleshooting
Issue	Solution
Helm timeout	Increase --timeout in workflow
ImagePullBackOff	Verify Docker Hub credentials
TLS error	Reissue Let’s Encrypt via Lightsail console
Autoscaler not working	Check CloudWatch logs for Lambda errors

🧾 License
MIT License © 2025
Created by Your Name / Your Organization

🤝 Contributing
Fork the repo

Create your feature branch (feature/my-feature)

Commit your changes

Push and open a PR against dev

Once merged, CI/CD will automatically deploy to the dev cluster

🌟 Summary
✅ Terraform — Infrastructure-as-Code
✅ Helm — Declarative App Deployments
✅ GitHub Actions — Full CI/CD Automation
✅ Autoscaling — Lambda-driven Horizontal Scaling
✅ Secure HTTPS — Managed by Lightsail
✅ Microservice-specific Deployments — Efficient and Isolated