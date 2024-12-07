#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "Please run this script as root."
    exit 1
fi

# Function to handle errors
handle_error() {
    echo "An error occurred. Exiting."
    exit 1
}
trap handle_error ERR

# Detect Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
echo "Detected Ubuntu version: $UBUNTU_VERSION"

# Validate supported versions
if [[ "$UBUNTU_VERSION" != "20.04" && "$UBUNTU_VERSION" != "22.04" ]]; then
    echo "This script only supports Ubuntu 20.04 and 22.04. Detected version: $UBUNTU_VERSION"
    exit 1
fi

echo "Updating system packages..."
apt update -y && apt upgrade -y

echo "Installing Docker and dependencies..."
apt install -y apt-transport-https ca-certificates curl software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list

apt update -y && apt install -y docker-ce docker-ce-cli containerd.io

echo "Installing Kubernetes packages..."
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
apt update -y && apt install -y kubelet kubeadm kubectl

echo "Initializing Kubernetes master..."
kubeadm init --pod-network-cidr=192.168.0.0/16 || handle_error

echo "Configuring kubeconfig for the current user..."
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

echo "Applying Calico CNI..."
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml || handle_error

echo "Generating join command for worker nodes..."
kubeadm token create --print-join-command > /join-command.sh
chmod +x /join-command.sh
echo "Join command saved to /join-command.sh. Share it with worker nodes."

