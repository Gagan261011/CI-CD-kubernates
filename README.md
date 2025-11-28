# DevOps Kubernetes Lab - Complete CI/CD Pipeline

A one-click lab environment for practicing DevOps with Kubernetes, Jenkins, SonarQube, and Nexus.

## 🎯 Overview

This project creates a complete DevOps infrastructure on AWS using Terraform, including:

- **Jenkins Server** - CI/CD automation
- **SonarQube Server** - Code quality analysis
- **Nexus Repository** - Artifact and Docker registry
- **Kubernetes Cluster** - 1 Master + 2 Workers (kubeadm)
- **Sample Spring Boot CRUD Application**

## 📁 Project Structure

```
CI-CD-kubernates/
├── terraform/                      # Infrastructure as Code
│   ├── main.tf                     # Provider configuration
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # Output values
│   ├── network.tf                  # VPC, Subnet, IGW
│   ├── security_groups.tf          # Security groups
│   ├── key_pair.tf                 # SSH key pairs
│   ├── ec2.tf                      # EC2 instances
│   └── scripts/                    # User data scripts
│       ├── jenkins_userdata.sh
│       ├── sonarqube_userdata.sh
│       ├── nexus_userdata.sh
│       ├── k8s_master_userdata.sh
│       └── k8s_worker_userdata.sh
├── app/                            # Spring Boot Application
│   ├── pom.xml
│   ├── Dockerfile
│   └── src/
├── k8s/                            # Kubernetes Manifests
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── Jenkinsfile                     # CI/CD Pipeline
└── README.md                       # This file
```

## 🚀 Quick Start

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
3. **Terraform** (>= 1.0.0) installed
4. **Git** installed

### Step 1: Clone and Configure

```bash
# Clone the repository
git clone <your-repo-url>
cd CI-CD-kubernates/terraform

# Review and modify variables if needed
# Edit terraform/variables.tf to change region, instance type, etc.
```

### Step 2: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply (create infrastructure)
terraform apply
```

**Wait ~10-15 minutes** for all servers to initialize.

### Step 3: Note the Outputs

After `terraform apply`, you'll see outputs like:

```
jenkins_url = "http://x.x.x.x:8080"
sonarqube_url = "http://x.x.x.x:9000"
nexus_url = "http://x.x.x.x:8081"
k8s_master_public_ip = "x.x.x.x"
...
```

**Save these IPs - you'll need them!**

---

## 🔧 Post-Deployment Configuration

### 1. Join Kubernetes Workers to Cluster

```bash
# SSH to K8s Master
ssh -i devops-lab-key.pem ubuntu@<K8S_MASTER_IP>

# Get the join command
cat /home/ubuntu/join-command.sh
```

Copy the join command, then run on each worker:

```bash
# SSH to Worker 1
ssh -i devops-lab-key.pem ubuntu@<K8S_WORKER_1_IP>
sudo <paste-join-command>

# SSH to Worker 2
ssh -i devops-lab-key.pem ubuntu@<K8S_WORKER_2_IP>
sudo <paste-join-command>
```

Verify on master:
```bash
kubectl get nodes
# Should show 1 master + 2 workers in Ready state
```

### 2. Configure kubectl on Jenkins

```bash
# SSH to Jenkins
ssh -i devops-lab-key.pem ubuntu@<JENKINS_IP>

# Copy kubeconfig from master
scp -o StrictHostKeyChecking=no -i /path/to/key ubuntu@<K8S_MASTER_IP>:/home/ubuntu/.kube/config /tmp/kubeconfig

sudo cp /tmp/kubeconfig /var/lib/jenkins/.kube/config
sudo chown jenkins:jenkins /var/lib/jenkins/.kube/config
sudo chmod 600 /var/lib/jenkins/.kube/config

# Test
sudo -u jenkins kubectl get nodes
```

### 3. Get Jenkins Initial Password

```bash
ssh -i devops-lab-key.pem ubuntu@<JENKINS_IP>
cat /home/ubuntu/jenkins_initial_password.txt
```

Access Jenkins at `http://<JENKINS_IP>:8080`:
1. Enter the initial admin password
2. Install suggested plugins
3. Create admin user
4. Complete setup wizard

### 4. Configure SonarQube

Access SonarQube at `http://<SONARQUBE_IP>:9000`:

1. Login with `admin` / `admin`
2. Change password when prompted
3. Generate a token:
   - Go to **Account** (top-right) → **Security**
   - Generate Token: Name it `jenkins-token`
   - **Save the token!**

### 5. Configure Nexus Repository

Access Nexus at `http://<NEXUS_IP>:8081`:

```bash
# Get initial admin password
ssh -i devops-lab-key.pem ubuntu@<NEXUS_IP>
cat /home/ubuntu/nexus_admin_password.txt
```

1. Login with `admin` and the password
2. Complete setup wizard, enable anonymous access (for lab)
3. **Create Docker Registry:**
   - Go to ⚙️ **Settings** → **Repositories** → **Create repository**
   - Select **docker (hosted)**
   - Name: `docker-hosted`
   - HTTP port: `8082`
   - Check "Allow anonymous docker pull"
   - Create repository

4. **Enable Docker Bearer Token Realm:**
   - Go to ⚙️ **Settings** → **Security** → **Realms**
   - Add `Docker Bearer Token Realm` to active
   - Save

### 6. Configure Jenkins Credentials

In Jenkins, go to **Manage Jenkins** → **Credentials** → **System** → **Global credentials**:

#### Add Nexus Credentials
- **Kind:** Username with password
- **ID:** `nexus-credentials`
- **Username:** `admin`
- **Password:** `<your-nexus-password>`

#### Add SonarQube Token
- **Kind:** Secret text
- **ID:** `sonarqube-token`
- **Secret:** `<your-sonarqube-token>`

### 7. Configure Jenkins Global Tools

Go to **Manage Jenkins** → **Tools**:

#### JDK
- Name: `JDK17`
- Install automatically (or use `/usr/lib/jvm/java-17-openjdk-amd64`)

#### Maven
- Name: `Maven3`
- Install automatically (or use `/usr/share/maven`)

### 8. Update Jenkinsfile with Actual IPs

Edit `Jenkinsfile` and replace placeholders:

```groovy
NEXUS_URL = '<NEXUS_IP>:8081'
NEXUS_DOCKER_REGISTRY = '<NEXUS_IP>:8082'
SONARQUBE_URL = 'http://<SONARQUBE_IP>:9000'
```

---

## 📋 Create Jenkins Pipeline Job

1. Go to Jenkins → **New Item**
2. Name: `crud-app-pipeline`
3. Type: **Pipeline**
4. Configure:
   - **Pipeline** → Definition: `Pipeline script from SCM`
   - SCM: Git
   - Repository URL: `<your-repo-url>` (or use local path)
   - Script Path: `Jenkinsfile`
5. Save

---

## ▶️ Run the Pipeline

1. Click **Build Now** on the pipeline job
2. Watch the pipeline stages:
   - ✅ Checkout
   - ✅ Build & Test
   - ✅ SonarQube Analysis
   - ✅ Quality Gate
   - ✅ Build Docker Image
   - ✅ Push to Nexus Registry
   - ✅ Deploy to Kubernetes
   - ✅ Sanity Check

3. Access the application:
   - URL: `http://<K8S_WORKER_IP>:30080`
   - Health: `http://<K8S_WORKER_IP>:30080/actuator/health`
   - API: `http://<K8S_WORKER_IP>:30080/api/items`

---

## 🌐 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/items/` | Health check |
| GET | `/api/items` | Get all items |
| GET | `/api/items/{id}` | Get item by ID |
| POST | `/api/items` | Create new item |
| PUT | `/api/items/{id}` | Update item |
| DELETE | `/api/items/{id}` | Delete item |
| GET | `/api/items/search?name=x` | Search by name |
| GET | `/actuator/health` | Application health |

### Sample API Requests

```bash
# Create an item
curl -X POST http://<WORKER_IP>:30080/api/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","description":"Dell XPS 15","price":1299.99,"quantity":10}'

# Get all items
curl http://<WORKER_IP>:30080/api/items

# Health check
curl http://<WORKER_IP>:30080/actuator/health
```

---

## 🧹 Cleanup

```bash
# Destroy all infrastructure
cd terraform
terraform destroy
```

---

## 🔍 Troubleshooting

### Kubernetes Nodes Not Ready
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check kubelet logs
journalctl -u kubelet -f
```

### Pods Not Starting
```bash
# Check pod status
kubectl get pods -n crud-app
kubectl describe pod <pod-name> -n crud-app
kubectl logs <pod-name> -n crud-app
```

### Docker Registry Issues
```bash
# Test registry access
curl http://<NEXUS_IP>:8082/v2/_catalog

# Check if insecure registries are configured
cat /etc/docker/daemon.json
```

### Jenkins Cannot Access Kubernetes
```bash
# Verify kubeconfig
sudo -u jenkins kubectl get nodes

# Check file permissions
ls -la /var/lib/jenkins/.kube/config
```

---

## 📚 Learning Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [Nexus Repository Documentation](https://help.sonatype.com/repomanager3)

---

## 📝 Notes

- This is a **learning lab environment** - not production-ready
- All traffic is on public IPs - add VPN/bastion for production
- Security groups are permissive - tighten for production
- No HTTPS configured - add SSL certificates for production
- H2 in-memory database - use persistent storage for production

---

## 🤝 Contributing

Feel free to submit issues and pull requests to improve this lab!

---

## 📄 License

MIT License - Feel free to use and modify for learning purposes.
