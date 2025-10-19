#!/bin/bash
set -e

echo "🚀 Installing K3s Master Node..."

MASTER_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
K3S_VERSION="v1.30.2+k3s1"
KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"

sudo apt-get update -y
sudo apt-get install -y curl unzip jq apt-transport-https ca-certificates gnupg lsb-release socat

# --- Install K3s Master ---
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${K3S_VERSION} sh -s - server \
  --write-kubeconfig-mode 644 \
  --tls-san ${MASTER_IP} \
  --disable traefik

sudo systemctl enable k3s
sudo systemctl status k3s --no-pager
echo "✅ K3s master installed."

# --- Install Helm ---
echo "⚙️ Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# --- Install NGINX Ingress ---
echo "🌐 Installing NGINX Ingress Controller..."
kubectl create namespace ingress-nginx || true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.https=32001 \
  --set controller.service.nodePorts.http=32000

echo "✅ NGINX Ingress Controller deployed."

# --- Configure Let's Encrypt via cert-manager ---
echo "🔐 Installing cert-manager for Let's Encrypt..."
kubectl create namespace cert-manager || true
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true

# Wait for cert-manager pods to be ready
kubectl rollout status deployment cert-manager -n cert-manager --timeout=120s || true

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: admin@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

echo "✅ Let's Encrypt ClusterIssuer configured."

# --- Save kubeconfig for Terraform ---
mkdir -p /home/ubuntu/kubeconfig
sudo cp ${KUBECONFIG_PATH} /home/ubuntu/kubeconfig/config
sudo chown ubuntu:ubuntu /home/ubuntu/kubeconfig/config

# Encode kubeconfig for GitHub Actions secret
KUBECONFIG_B64=$(base64 -w0 /home/ubuntu/kubeconfig/config)
echo "${KUBECONFIG_B64}" > /home/ubuntu/kubeconfig/config.b64

echo "✅ K3s Master setup complete."
echo "🌐 Access your cluster with: export KUBECONFIG=/home/ubuntu/kubeconfig/config"
