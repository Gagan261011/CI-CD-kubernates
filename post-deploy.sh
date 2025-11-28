#!/bin/bash
# ============================================
# POST-DEPLOYMENT CONFIGURATION SCRIPT
# Run this after terraform apply completes
# ============================================

set -e

echo "============================================"
echo "DevOps Kubernetes Lab - Post Deployment Setup"
echo "============================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if terraform outputs are available
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform is not installed. Please install terraform first.${NC}"
    exit 1
fi

# Get outputs from Terraform
echo -e "${YELLOW}Fetching Terraform outputs...${NC}"
cd terraform

JENKINS_IP=$(terraform output -raw jenkins_public_ip 2>/dev/null || echo "")
SONARQUBE_IP=$(terraform output -raw sonarqube_public_ip 2>/dev/null || echo "")
NEXUS_IP=$(terraform output -raw nexus_public_ip 2>/dev/null || echo "")
K8S_MASTER_IP=$(terraform output -raw k8s_master_public_ip 2>/dev/null || echo "")
K8S_WORKER_1_IP=$(terraform output -raw k8s_worker_1_public_ip 2>/dev/null || echo "")
K8S_WORKER_2_IP=$(terraform output -raw k8s_worker_2_public_ip 2>/dev/null || echo "")
KEY_FILE="devops-lab-key.pem"

if [ -z "$JENKINS_IP" ]; then
    echo -e "${RED}Could not get Terraform outputs. Make sure terraform apply was successful.${NC}"
    exit 1
fi

cd ..

echo ""
echo "============================================"
echo "INFRASTRUCTURE DETAILS"
echo "============================================"
echo -e "Jenkins:      ${GREEN}http://$JENKINS_IP:8080${NC}"
echo -e "SonarQube:    ${GREEN}http://$SONARQUBE_IP:9000${NC}"
echo -e "Nexus:        ${GREEN}http://$NEXUS_IP:8081${NC}"
echo -e "Nexus Docker: ${GREEN}$NEXUS_IP:8082${NC}"
echo -e "K8s Master:   ${GREEN}$K8S_MASTER_IP${NC}"
echo -e "K8s Worker 1: ${GREEN}$K8S_WORKER_1_IP${NC}"
echo -e "K8s Worker 2: ${GREEN}$K8S_WORKER_2_IP${NC}"
echo ""

# Update Jenkinsfile with actual IPs
echo -e "${YELLOW}Updating Jenkinsfile with actual IPs...${NC}"
sed -i "s/NEXUS_IP:8081/$NEXUS_IP:8081/g" Jenkinsfile
sed -i "s/NEXUS_IP:8082/$NEXUS_IP:8082/g" Jenkinsfile
sed -i "s/SONARQUBE_IP:9000/$SONARQUBE_IP:9000/g" Jenkinsfile
echo -e "${GREEN}✓ Jenkinsfile updated${NC}"

# Update K8s deployment template
echo -e "${YELLOW}Updating Kubernetes deployment template...${NC}"
sed -i "s/NEXUS_IP:8082/$NEXUS_IP:8082/g" k8s/deployment.yaml
sed -i "s/NEXUS_IP:8082/$NEXUS_IP:8082/g" k8s/kustomization.yaml
echo -e "${GREEN}✓ K8s manifests updated${NC}"

echo ""
echo "============================================"
echo "NEXT STEPS (Manual)"
echo "============================================"
echo ""
echo -e "${YELLOW}1. Wait 10-15 minutes for servers to initialize${NC}"
echo ""
echo -e "${YELLOW}2. Join Kubernetes workers to cluster:${NC}"
echo "   # SSH to master and get join command:"
echo "   ssh -i terraform/$KEY_FILE ubuntu@$K8S_MASTER_IP"
echo "   cat /home/ubuntu/join-command.sh"
echo ""
echo "   # Run join command on each worker:"
echo "   ssh -i terraform/$KEY_FILE ubuntu@$K8S_WORKER_1_IP"
echo "   sudo <join-command>"
echo ""
echo "   ssh -i terraform/$KEY_FILE ubuntu@$K8S_WORKER_2_IP"
echo "   sudo <join-command>"
echo ""
echo -e "${YELLOW}3. Get Jenkins initial password:${NC}"
echo "   ssh -i terraform/$KEY_FILE ubuntu@$JENKINS_IP"
echo "   cat /home/ubuntu/jenkins_initial_password.txt"
echo ""
echo -e "${YELLOW}4. Get Nexus admin password:${NC}"
echo "   ssh -i terraform/$KEY_FILE ubuntu@$NEXUS_IP"
echo "   cat /home/ubuntu/nexus_admin_password.txt"
echo ""
echo -e "${YELLOW}5. Configure kubectl on Jenkins:${NC}"
echo "   ssh -i terraform/$KEY_FILE ubuntu@$JENKINS_IP"
echo "   # Copy kubeconfig from master"
echo ""
echo -e "${GREEN}See README.md for detailed configuration steps!${NC}"
echo ""
