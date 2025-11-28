#!/bin/bash
# ============================================
# COMPLETE SETUP SCRIPT
# Automates post-deployment configuration
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_step() {
    echo -e "${YELLOW}→ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check arguments
if [ "$#" -lt 6 ]; then
    echo "Usage: $0 <SSH_KEY_PATH> <JENKINS_IP> <NEXUS_IP> <K8S_MASTER_IP> <K8S_WORKER_1_IP> <K8S_WORKER_2_IP>"
    echo ""
    echo "Example:"
    echo "  $0 ./terraform/devops-lab-key.pem 1.2.3.4 1.2.3.5 1.2.3.6 1.2.3.7 1.2.3.8"
    exit 1
fi

SSH_KEY=$1
JENKINS_IP=$2
NEXUS_IP=$3
K8S_MASTER_IP=$4
K8S_WORKER_1_IP=$5
K8S_WORKER_2_IP=$6

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

print_header "DevOps Kubernetes Lab - Complete Setup"

echo "Configuration:"
echo "  SSH Key: $SSH_KEY"
echo "  Jenkins: $JENKINS_IP"
echo "  Nexus: $NEXUS_IP"
echo "  K8s Master: $K8S_MASTER_IP"
echo "  K8s Worker 1: $K8S_WORKER_1_IP"
echo "  K8s Worker 2: $K8S_WORKER_2_IP"

# Verify SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    print_error "SSH key not found: $SSH_KEY"
    exit 1
fi

chmod 400 "$SSH_KEY"

# ==========================================
# Step 1: Wait for servers to be ready
# ==========================================
print_header "Step 1: Waiting for servers to be ready"

wait_for_ssh() {
    local host=$1
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$host "echo 'SSH ready'" 2>/dev/null; then
            return 0
        fi
        echo "  Waiting for $host... (attempt $attempt/$max_attempts)"
        sleep 10
        attempt=$((attempt + 1))
    done
    return 1
}

print_step "Checking K8s Master..."
wait_for_ssh $K8S_MASTER_IP && print_success "K8s Master ready" || print_error "K8s Master not reachable"

print_step "Checking K8s Workers..."
wait_for_ssh $K8S_WORKER_1_IP && print_success "K8s Worker 1 ready" || print_error "K8s Worker 1 not reachable"
wait_for_ssh $K8S_WORKER_2_IP && print_success "K8s Worker 2 ready" || print_error "K8s Worker 2 not reachable"

print_step "Checking Jenkins..."
wait_for_ssh $JENKINS_IP && print_success "Jenkins ready" || print_error "Jenkins not reachable"

# ==========================================
# Step 2: Get join command from K8s Master
# ==========================================
print_header "Step 2: Getting Kubernetes join command"

# Wait for kubeadm init to complete
print_step "Waiting for kubeadm init to complete..."
ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$K8S_MASTER_IP "while [ ! -f /home/ubuntu/join-command.sh ]; do sleep 10; done"

JOIN_COMMAND=$(ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$K8S_MASTER_IP "cat /home/ubuntu/join-command.sh")
print_success "Got join command"

# ==========================================
# Step 3: Configure insecure registry on K8s nodes
# ==========================================
print_header "Step 3: Configuring insecure registry on K8s nodes"

REGISTRY_CONFIG="
cat > /tmp/containerd-config.toml <<'CONTAINERDEOF'
version = 2
[plugins]
  [plugins.\"io.containerd.grpc.v1.cri\"]
    [plugins.\"io.containerd.grpc.v1.cri\".registry]
      [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors]
        [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"$NEXUS_IP:8082\"]
          endpoint = [\"http://$NEXUS_IP:8082\"]
      [plugins.\"io.containerd.grpc.v1.cri\".registry.configs]
        [plugins.\"io.containerd.grpc.v1.cri\".registry.configs.\"$NEXUS_IP:8082\".tls]
          insecure_skip_verify = true
    [plugins.\"io.containerd.grpc.v1.cri\".containerd]
      [plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes]
        [plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc]
          runtime_type = \"io.containerd.runc.v2\"
          [plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc.options]
            SystemdCgroup = true
CONTAINERDEOF
sudo cp /tmp/containerd-config.toml /etc/containerd/config.toml
sudo systemctl restart containerd
"

print_step "Configuring K8s Master..."
ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$K8S_MASTER_IP "$REGISTRY_CONFIG" && print_success "K8s Master configured"

print_step "Configuring K8s Worker 1..."
ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$K8S_WORKER_1_IP "$REGISTRY_CONFIG" && print_success "K8s Worker 1 configured"

print_step "Configuring K8s Worker 2..."
ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$K8S_WORKER_2_IP "$REGISTRY_CONFIG" && print_success "K8s Worker 2 configured"

# ==========================================
# Step 4: Join workers to cluster
# ==========================================
print_header "Step 4: Joining workers to Kubernetes cluster"

print_step "Joining Worker 1..."
ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$K8S_WORKER_1_IP "sudo $JOIN_COMMAND" && print_success "Worker 1 joined"

print_step "Joining Worker 2..."
ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$K8S_WORKER_2_IP "sudo $JOIN_COMMAND" && print_success "Worker 2 joined"

# Wait for nodes to be ready
print_step "Waiting for nodes to be ready..."
sleep 30

print_step "Verifying cluster..."
ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$K8S_MASTER_IP "kubectl get nodes"

# ==========================================
# Step 5: Copy kubeconfig to Jenkins
# ==========================================
print_header "Step 5: Configuring kubectl on Jenkins"

print_step "Copying kubeconfig to Jenkins..."

# Get kubeconfig from master
ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$K8S_MASTER_IP "cat /home/ubuntu/.kube/config" > /tmp/kubeconfig

# Update the server address to use public IP
sed -i "s|server: https://.*:6443|server: https://$K8S_MASTER_IP:6443|g" /tmp/kubeconfig

# Copy to Jenkins
scp $SSH_OPTS -i "$SSH_KEY" /tmp/kubeconfig ubuntu@$JENKINS_IP:/tmp/kubeconfig

# Configure Jenkins
ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$JENKINS_IP "
    sudo mkdir -p /var/lib/jenkins/.kube
    sudo cp /tmp/kubeconfig /var/lib/jenkins/.kube/config
    sudo chown jenkins:jenkins /var/lib/jenkins/.kube/config
    sudo chmod 600 /var/lib/jenkins/.kube/config
"

print_step "Verifying kubectl on Jenkins..."
ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$JENKINS_IP "sudo -u jenkins kubectl get nodes" && print_success "kubectl configured on Jenkins"

# ==========================================
# Step 6: Configure Docker on Jenkins
# ==========================================
print_header "Step 6: Configuring Docker on Jenkins for Nexus registry"

ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$JENKINS_IP "
    # Configure Docker daemon for insecure registry
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    \"insecure-registries\": [\"$NEXUS_IP:8082\"]
}
EOF
    sudo systemctl restart docker
"
print_success "Docker configured on Jenkins"

# ==========================================
# Step 7: Get credentials
# ==========================================
print_header "Step 7: Retrieving credentials"

print_step "Jenkins initial password:"
ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$JENKINS_IP "cat /home/ubuntu/jenkins_initial_password.txt" 2>/dev/null || echo "  (waiting for Jenkins to start...)"

print_step "Nexus admin password:"
ssh $SSH_OPTS -i "$SSH_KEY" ubuntu@$NEXUS_IP "cat /home/ubuntu/nexus_admin_password.txt 2>/dev/null || echo '  (waiting for Nexus to start...)'"

# ==========================================
# Summary
# ==========================================
print_header "Setup Complete!"

echo ""
echo "Access URLs:"
echo "  Jenkins:   http://$JENKINS_IP:8080"
echo "  SonarQube: http://SONARQUBE_IP:9000 (admin/admin)"
echo "  Nexus:     http://$NEXUS_IP:8081"
echo ""
echo "Kubernetes Cluster:"
echo "  Master: $K8S_MASTER_IP"
echo "  Worker 1: $K8S_WORKER_1_IP"
echo "  Worker 2: $K8S_WORKER_2_IP"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Access Jenkins and complete setup wizard"
echo "2. Access Nexus and configure Docker registry on port 8082"
echo "3. Access SonarQube and generate token for Jenkins"
echo "4. Configure Jenkins credentials (nexus-credentials, sonarqube-token)"
echo "5. Create and run the pipeline!"
echo ""
echo -e "${GREEN}See README.md for detailed instructions${NC}"
