#!/bin/bash
# ============================================
# JENKINS SERVER USER DATA SCRIPT
# Installs: Java 17, Jenkins, Maven, Git, Docker, kubectl
# ============================================

set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "=========================================="
echo "Starting Jenkins Server Setup"
echo "=========================================="

# Update system
apt-get update -y
apt-get upgrade -y

# Install required packages
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    unzip \
    wget

# ==========================================
# Install Java 17
# ==========================================
echo "Installing Java 17..."
apt-get install -y openjdk-17-jdk
echo "JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" >> /etc/environment
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# ==========================================
# Install Maven
# ==========================================
echo "Installing Maven..."
apt-get install -y maven

# ==========================================
# Install Git
# ==========================================
echo "Installing Git..."
apt-get install -y git

# ==========================================
# Install Docker
# ==========================================
echo "Installing Docker..."

# Add Docker's official GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Add jenkins user to docker group (will be created by Jenkins installation)
# We'll do this after Jenkins is installed

# ==========================================
# Install kubectl
# ==========================================
echo "Installing kubectl..."

# Download kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install kubectl
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client

# ==========================================
# Install Jenkins
# ==========================================
echo "Installing Jenkins..."

# Add Jenkins repository key
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null

# Add Jenkins apt repository
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update apt and install Jenkins
apt-get update -y
apt-get install -y jenkins

# Add jenkins user to docker group
usermod -aG docker jenkins

# Start and enable Jenkins
systemctl start jenkins
systemctl enable jenkins

# Wait for Jenkins to start
echo "Waiting for Jenkins to start..."
sleep 60

# ==========================================
# Configure Jenkins
# ==========================================
echo "Configuring Jenkins..."

# Wait for Jenkins to be fully ready
until curl -s -o /dev/null -w "%%{http_code}" http://localhost:8080 | grep -q "200\|403"; do
    echo "Waiting for Jenkins..."
    sleep 10
done

# Get initial admin password
JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)

# Download Jenkins CLI
wget http://localhost:8080/jnlpJars/jenkins-cli.jar -O /tmp/jenkins-cli.jar 2>/dev/null || true

# Install plugins using CLI (if available)
PLUGINS=(
    "workflow-aggregator"
    "git"
    "github"
    "maven-plugin"
    "sonar"
    "docker-workflow"
    "docker-plugin"
    "kubernetes"
    "kubernetes-cli"
    "credentials"
    "credentials-binding"
    "pipeline-stage-view"
    "pipeline-utility-steps"
    "ws-cleanup"
    "timestamper"
    "build-timeout"
)

# Try to install plugins
for plugin in "$${PLUGINS[@]}"; do
    java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ -auth admin:$JENKINS_PASSWORD install-plugin $plugin -deploy 2>/dev/null || echo "Plugin $plugin installation will be done manually"
done

# Restart Jenkins to activate plugins
systemctl restart jenkins || true

# ==========================================
# Create directory for kubeconfig
# ==========================================
echo "Creating kubeconfig directory for Jenkins..."
mkdir -p /var/lib/jenkins/.kube
chown jenkins:jenkins /var/lib/jenkins/.kube

# Create a script to fetch kubeconfig from master
cat > /home/ubuntu/fetch-kubeconfig.sh <<'FETCH_SCRIPT'
#!/bin/bash
# This script fetches kubeconfig from K8s master
# Run this manually after the K8s master is ready

if [ -z "$1" ]; then
    echo "Usage: $0 <k8s-master-ip>"
    exit 1
fi

K8S_MASTER_IP=$1

echo "Fetching kubeconfig from K8s master at $K8S_MASTER_IP..."
scp -o StrictHostKeyChecking=no -i ${key_path} ubuntu@$K8S_MASTER_IP:/home/ubuntu/.kube/config /tmp/kubeconfig

sudo cp /tmp/kubeconfig /var/lib/jenkins/.kube/config
sudo chown jenkins:jenkins /var/lib/jenkins/.kube/config
sudo chmod 600 /var/lib/jenkins/.kube/config

echo "Kubeconfig installed for Jenkins user"
FETCH_SCRIPT

chmod +x /home/ubuntu/fetch-kubeconfig.sh
chown ubuntu:ubuntu /home/ubuntu/fetch-kubeconfig.sh

# ==========================================
# Create directory for sample app
# ==========================================
mkdir -p /opt/sample-app
chown jenkins:jenkins /opt/sample-app

echo "=========================================="
echo "Jenkins Server Setup Complete!"
echo "Initial Admin Password: $JENKINS_PASSWORD"
echo "=========================================="
echo "IMPORTANT: Run the following command to configure kubectl:"
echo "  /home/ubuntu/fetch-kubeconfig.sh <k8s-master-ip>"
echo "=========================================="

# Save initial password to a known location
echo $JENKINS_PASSWORD > /home/ubuntu/jenkins_initial_password.txt
chmod 644 /home/ubuntu/jenkins_initial_password.txt

# Create marker file
echo "Jenkins setup complete" > /home/ubuntu/jenkins_ready.txt
