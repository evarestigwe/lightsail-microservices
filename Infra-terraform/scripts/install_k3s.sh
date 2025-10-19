#!/bin/bash
set -e

ROLE=$1
MASTER_IP=$2

if [ -z "$ROLE" ]; then
  echo "❌ Usage: ./install_k3s.sh [master|worker] <MASTER_IP (for workers)>"
  exit 1
fi

echo "🚀 Starting K3s ${ROLE} installation..."

if [ "$ROLE" == "master" ]; then
  /bin/bash /home/ubuntu/install_k3s_master.sh
elif [ "$ROLE" == "worker" ]; then
  if [ -z "$MASTER_IP" ]; then
    echo "❌ MASTER_IP is required for worker nodes."
    exit 1
  fi
  /bin/bash /home/ubuntu/install_k3s_worker.sh ${MASTER_IP}
else
  echo "❌ Invalid role: ${ROLE}. Use 'master' or 'worker'."
  exit 1
fi
