#!/bin/bash
set -e

MASTER_IP=$1

if [ -z "$MASTER_IP" ]; then
  echo "❌ ERROR: Master IP not provided."
  echo "Usage: ./install_k3s_worker.sh <MASTER_IP>"
  exit 1
fi

echo "🚀 Installing K3s Worker Node..."
echo "Joining cluster at ${MASTER_IP}..."

# --- Update & Install Base Packages ---
sudo apt-get update -y
sudo apt-get install -y curl jq socat apt-transport-https ca-certificates

# --- Wait for master token to be available ---
echo "⏳ Waiting for master node token to become available..."
until curl -sf http://${MASTER_IP}:6443 >/dev/null 2>&1; do
  sleep 5
  echo "Waiting for K3s master API to be ready..."
done

# --- Retrieve Node Token from Master ---
TOKEN=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ubuntu@${MASTER_IP} "sudo cat /var/lib/rancher/k3s/server/node-token")
if [ -z "$TOKEN" ]; then
  echo "❌ ERROR: Could not retrieve join token from master."
  exit 1
fi

# --- Install K3s Agent (Worker) ---
curl -sfL https://get.k3s.io | K3S_URL="https://${MASTER_IP}:6443" K3S_TOKEN="${TOKEN}" sh -s - agent

# --- Enable & Start ---
sudo systemctl enable k3s-agent
sudo systemctl start k3s-agent

echo "✅ Worker node successfully joined K3s cluster."
