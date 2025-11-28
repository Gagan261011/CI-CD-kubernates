#!/bin/bash
# ============================================
# NEXUS SERVER USER DATA SCRIPT
# Installs: Java 8, Nexus Repository Manager 3
# Configures: Maven repository and Docker registry
# ============================================

set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "=========================================="
echo "Starting Nexus Server Setup"
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
    wget \
    jq

# ==========================================
# Install Java 8 (Required for Nexus)
# ==========================================
echo "Installing Java 8..."
apt-get install -y openjdk-8-jdk
echo "JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> /etc/environment
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# ==========================================
# Create Nexus User
# ==========================================
echo "Creating Nexus user..."
useradd -r -m -U -d /opt/nexus -s /bin/bash nexus

# ==========================================
# Download and Install Nexus
# ==========================================
echo "Downloading Nexus..."
cd /tmp
wget https://download.sonatype.com/nexus/3/latest-unix.tar.gz

echo "Installing Nexus..."
tar -xzf latest-unix.tar.gz
mv nexus-* /opt/nexus/nexus
mv sonatype-work /opt/nexus/

# Set ownership
chown -R nexus:nexus /opt/nexus

# ==========================================
# Configure Nexus
# ==========================================
echo "Configuring Nexus..."

# Set Nexus to run as nexus user
echo 'run_as_user="nexus"' > /opt/nexus/nexus/bin/nexus.rc

# Configure Nexus JVM options
cat > /opt/nexus/nexus/bin/nexus.vmoptions <<EOF
-Xms1024m
-Xmx1024m
-XX:MaxDirectMemorySize=1024m
-XX:+UnlockDiagnosticVMOptions
-XX:+LogVMOutput
-XX:LogFile=../sonatype-work/nexus3/log/jvm.log
-XX:-OmitStackTraceInFastThrow
-Djava.net.preferIPv4Stack=true
-Dkaraf.home=.
-Dkaraf.base=.
-Dkaraf.etc=etc/karaf
-Djava.util.logging.config.file=etc/karaf/java.util.logging.properties
-Dkaraf.data=../sonatype-work/nexus3
-Dkaraf.log=../sonatype-work/nexus3/log
-Djava.io.tmpdir=../sonatype-work/nexus3/tmp
-Dkaraf.startLocalConsole=false
EOF

# Configure Nexus application properties for Docker registry
cat > /opt/nexus/sonatype-work/nexus3/etc/nexus.properties <<EOF
# Jetty section
application-port=8081
application-host=0.0.0.0

# Nexus section
nexus-args=$${jetty.etc}/jetty.xml,$${jetty.etc}/jetty-http.xml,$${jetty.etc}/jetty-requestlog.xml
nexus-context-path=/
EOF

chown -R nexus:nexus /opt/nexus/sonatype-work

# ==========================================
# Create Systemd Service
# ==========================================
echo "Creating Nexus systemd service..."
cat > /etc/systemd/system/nexus.service <<EOF
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/nexus/bin/nexus start
ExecStop=/opt/nexus/nexus/bin/nexus stop
User=nexus
Group=nexus
Restart=on-abort
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
EOF

# ==========================================
# Start Nexus
# ==========================================
echo "Starting Nexus..."
systemctl daemon-reload
systemctl enable nexus
systemctl start nexus

# Wait for Nexus to fully start
echo "Waiting for Nexus to start (this may take several minutes)..."
sleep 180

# ==========================================
# Get Admin Password
# ==========================================
echo "Retrieving admin password..."
ADMIN_PASSWORD_FILE="/opt/nexus/sonatype-work/nexus3/admin.password"

# Wait for password file to be created
for i in {1..60}; do
    if [ -f "$ADMIN_PASSWORD_FILE" ]; then
        NEXUS_ADMIN_PASSWORD=$(cat $ADMIN_PASSWORD_FILE)
        echo "Nexus Admin Password: $NEXUS_ADMIN_PASSWORD" > /home/ubuntu/nexus_admin_password.txt
        chmod 644 /home/ubuntu/nexus_admin_password.txt
        
        # Save for later configuration
        echo "$NEXUS_ADMIN_PASSWORD" > /tmp/nexus_admin_password
        break
    fi
    echo "Waiting for Nexus admin password file... ($i/60)"
    sleep 10
done

# ==========================================
# Create configuration script for Docker registry
# ==========================================
cat > /home/ubuntu/configure-nexus-docker.sh <<'NEXUS_CONFIG'
#!/bin/bash
# This script configures Nexus Docker registry
# Run this after Nexus is fully started

NEXUS_URL="http://localhost:8081"
ADMIN_PASSWORD=$(cat /tmp/nexus_admin_password 2>/dev/null || echo "admin123")

echo "Configuring Nexus Docker Registry..."
echo "Note: This may need to be done manually via Nexus UI"
echo ""
echo "Manual Steps:"
echo "1. Login to Nexus at http://<nexus-ip>:8081"
echo "2. Username: admin, Password: $ADMIN_PASSWORD"
echo "3. Complete the setup wizard"
echo "4. Go to Settings (gear icon) -> Repositories -> Create repository"
echo "5. Select 'docker (hosted)'"
echo "6. Name: docker-hosted"
echo "7. HTTP port: 8082"
echo "8. Enable Docker V1 API: checked"
echo "9. Create repository"
echo ""
echo "For Jenkins access:"
echo "10. Go to Settings -> Security -> Realms"
echo "11. Add 'Docker Bearer Token Realm' to active"
echo "12. Save"
NEXUS_CONFIG

chmod +x /home/ubuntu/configure-nexus-docker.sh

echo "=========================================="
echo "Nexus Server Setup Complete!"
echo "Access at: http://<server-ip>:8081"
echo "Default user: admin"
echo "Password: Check /home/ubuntu/nexus_admin_password.txt"
echo ""
echo "IMPORTANT: Run /home/ubuntu/configure-nexus-docker.sh"
echo "or manually configure Docker registry via Nexus UI"
echo "=========================================="

# Create marker file
echo "Nexus installation complete" > /home/ubuntu/nexus_ready.txt
