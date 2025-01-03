#!/bin/bash

set -euo pipefail

ROLE=${1:-}
JOIN_CMD=${2:-}

# Colors for output
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
RESET="\033[0m"

log() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${RESET}"
}

error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${RESET}" >&2
  exit 1
}

if [ -z "$ROLE" ]; then
  error "Usage: $0 <master|worker> [join_command (for worker)]"
fi

log "Updating and upgrading the system..."
sudo apt update && sudo apt upgrade -y

log "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

log "Loading kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

log "Setting sysctl parameters for Kubernetes networking..."
cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

log "Installing required packages..."
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

log "Adding Docker repository and installing containerd..."
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y containerd.io

log "Configuring containerd..."
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

log "Adding Kubernetes repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

log "Installing Kubernetes components..."
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

if [ "$ROLE" = "master" ]; then
  log "Initializing Kubernetes control plane..."
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16 || error "Failed to initialize the Kubernetes control plane."

  log "Setting up kubeconfig for the master node..."
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  log "Deploying Calico network plugin for pod communication..."
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml || error "Failed to deploy the Calico network plugin."

  log "Cluster initialization complete. Retrieving join command..."
  JOIN_COMMAND=$(sudo kubeadm token create --print-join-command) || error "Failed to generate join command."
  log "Use the following command to join worker nodes:"
  echo -e "${YELLOW}${JOIN_COMMAND}${RESET}"

elif [ "$ROLE" = "worker" ]; then
  if [ -z "$JOIN_CMD" ]; then
    error "For 'worker', you must provide the 'join_command' as the second argument."
  fi

  log "Joining the cluster as a worker node..."
  eval "$JOIN_CMD" || error "Failed to join the Kubernetes cluster."

  log "Worker node setup complete."

else
  error "Invalid role: $ROLE. Please specify 'master' or 'worker'."
fi
sudo systemctl enable kubelet --now
log "Script execution completed successfully!"
