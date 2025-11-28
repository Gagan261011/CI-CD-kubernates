#!/bin/bash
# ============================================
# KUBERNETES WORKER USER DATA SCRIPT
# Installs: containerd, kubeadm, kubelet, kubectl
# Joins the Kubernetes cluster
# ============================================

set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "=========================================="
echo "Starting Kubernetes Worker Setup"
echo "=========================================="

# Update system
apt-get update -y
apt-get upgrade -y

# ==========================================
# Disable Swap (required for Kubernetes)
# ==========================================
echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# ==========================================
# Load Required Kernel Modules
# ==========================================
echo "Loading kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# ==========================================
# Set Sysctl Parameters for Kubernetes
# ==========================================
echo "Setting sysctl parameters..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# ==========================================
# Install containerd
# ==========================================
echo "Installing containerd..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

# Add Docker's official GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# Enable SystemdCgroup in containerd
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart containerd
systemctl restart containerd
systemctl enable containerd

# ==========================================
# Install kubeadm, kubelet, kubectl
# ==========================================
echo "Installing Kubernetes components..."

# Add Kubernetes GPG key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes apt repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Enable kubelet
systemctl enable kubelet

# ==========================================
# Wait for master to be ready and join cluster
# ==========================================
echo "Waiting for master node to be ready..."
sleep 120  # Give master time to initialize

# Try to fetch and execute join command from master
# This will be populated by Terraform via template
${join_command}

echo "=========================================="
echo "Kubernetes Worker Setup Complete!"
echo "=========================================="

# Create marker file
echo "K8s worker setup complete" > /home/ubuntu/k8s_worker_ready.txt
