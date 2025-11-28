#!/bin/bash
# ============================================
# KUBERNETES MASTER USER DATA SCRIPT
# Installs: containerd, kubeadm, kubelet, kubectl
# Initializes Kubernetes cluster with kubeadm
# ============================================

set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "=========================================="
echo "Starting Kubernetes Master Setup"
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
# Initialize Kubernetes Cluster
# ==========================================
echo "Initializing Kubernetes cluster..."

# Get the private IP of this instance
PRIVATE_IP=$(hostname -I | awk '{print $1}')

# Initialize cluster
kubeadm init \
  --pod-network-cidr=${pod_network_cidr} \
  --apiserver-advertise-address=$PRIVATE_IP \
  --node-name=$(hostname -s) | tee /var/log/kubeadm-init.log

# ==========================================
# Configure kubectl for root
# ==========================================
echo "Configuring kubectl for root..."
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

# ==========================================
# Configure kubectl for ubuntu user
# ==========================================
echo "Configuring kubectl for ubuntu user..."
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# ==========================================
# Install Calico CNI Plugin
# ==========================================
echo "Installing Calico CNI..."
kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f https://docs.projectcalico.org/manifests/calico.yaml

# ==========================================
# Save Join Command
# ==========================================
echo "Saving join command..."
kubeadm token create --print-join-command > /home/ubuntu/join-command.sh
chmod +x /home/ubuntu/join-command.sh
chown ubuntu:ubuntu /home/ubuntu/join-command.sh

# Also save to a known location for Jenkins to access later
cp /home/ubuntu/join-command.sh /tmp/join-command.sh
chmod 644 /tmp/join-command.sh

# ==========================================
# Wait for all system pods to be ready
# ==========================================
echo "Waiting for system pods to be ready..."
sleep 30

# ==========================================
# Display cluster status
# ==========================================
echo "=========================================="
echo "Kubernetes Master Setup Complete!"
echo "Cluster Info:"
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes
kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods --all-namespaces
echo "=========================================="
echo "Join command saved to /home/ubuntu/join-command.sh"
echo "Kubeconfig saved to /home/ubuntu/.kube/config"
echo "=========================================="

# Create marker file
echo "K8s master setup complete" > /home/ubuntu/k8s_master_ready.txt
