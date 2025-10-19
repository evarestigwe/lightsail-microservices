#!/bin/bash
set -e

# Update and install dependencies
sudo apt-get update -y
sudo apt-get install -y curl

# Install k3s (master node)
curl -sfL https://get.k3s.io | sh -

# Wait for kubeconfig
sleep 20

# Copy kubeconfig for access
sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/k3s.yaml
sudo chown ubuntu:ubuntu /home/ubuntu/k3s.yaml

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
