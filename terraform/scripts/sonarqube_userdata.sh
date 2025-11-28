#!/bin/bash
# ============================================
# SONARQUBE SERVER USER DATA SCRIPT
# Installs: Java 17, SonarQube Community Edition
# ============================================

set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "=========================================="
echo "Starting SonarQube Server Setup"
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
# Configure System for SonarQube
# ==========================================
echo "Configuring system for SonarQube..."

# Increase virtual memory
sysctl -w vm.max_map_count=524288
sysctl -w fs.file-max=131072
echo "vm.max_map_count=524288" >> /etc/sysctl.conf
echo "fs.file-max=131072" >> /etc/sysctl.conf

# Set ulimits
cat >> /etc/security/limits.conf <<EOF
sonarqube   -   nofile   131072
sonarqube   -   nproc    8192
EOF

# ==========================================
# Create SonarQube User
# ==========================================
echo "Creating SonarQube user..."
useradd -r -m -U -d /opt/sonarqube -s /bin/bash sonarqube

# ==========================================
# Download and Install SonarQube
# ==========================================
echo "Downloading SonarQube..."
SONARQUBE_VERSION="10.3.0.82913"
cd /tmp
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$${SONARQUBE_VERSION}.zip

echo "Installing SonarQube..."
unzip sonarqube-$${SONARQUBE_VERSION}.zip
mv sonarqube-$${SONARQUBE_VERSION} /opt/sonarqube/sonarqube

# Set ownership
chown -R sonarqube:sonarqube /opt/sonarqube

# ==========================================
# Configure SonarQube
# ==========================================
echo "Configuring SonarQube..."
cat > /opt/sonarqube/sonarqube/conf/sonar.properties <<EOF
# SonarQube Configuration
sonar.web.host=0.0.0.0
sonar.web.port=9000

# Elasticsearch settings
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:MaxDirectMemorySize=256m -XX:+HeapDumpOnOutOfMemoryError

# Web server settings
sonar.web.javaOpts=-Xmx512m -Xms128m -XX:+HeapDumpOnOutOfMemoryError

# Compute Engine settings
sonar.ce.javaOpts=-Xmx512m -Xms128m -XX:+HeapDumpOnOutOfMemoryError
EOF

# ==========================================
# Create Systemd Service
# ==========================================
echo "Creating SonarQube systemd service..."
cat > /etc/systemd/system/sonarqube.service <<EOF
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
LimitNOFILE=131072
LimitNPROC=8192

[Install]
WantedBy=multi-user.target
EOF

# ==========================================
# Start SonarQube
# ==========================================
echo "Starting SonarQube..."
systemctl daemon-reload
systemctl enable sonarqube
systemctl start sonarqube

echo "=========================================="
echo "SonarQube Server Setup Complete!"
echo "Default credentials: admin / admin"
echo "Access at: http://<server-ip>:9000"
echo "=========================================="

# Wait for SonarQube to start and create a marker file
sleep 30
echo "SonarQube installation complete" > /home/ubuntu/sonarqube_ready.txt
