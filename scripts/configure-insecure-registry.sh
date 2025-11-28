#!/bin/bash
# ============================================
# CONFIGURE INSECURE REGISTRY ON K8S NODES
# Run this script on K8s master and workers to allow
# pulling from Nexus Docker registry without HTTPS
# ============================================

if [ -z "$1" ]; then
    echo "Usage: $0 <NEXUS_IP>"
    echo "Example: $0 10.0.1.50"
    exit 1
fi

NEXUS_IP=$1
DOCKER_REGISTRY="$NEXUS_IP:8082"

echo "Configuring insecure registry: $DOCKER_REGISTRY"

# Configure containerd to use insecure registry
cat > /etc/containerd/config.toml <<EOF
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."$DOCKER_REGISTRY"]
          endpoint = ["http://$DOCKER_REGISTRY"]
      [plugins."io.containerd.grpc.v1.cri".registry.configs]
        [plugins."io.containerd.grpc.v1.cri".registry.configs."$DOCKER_REGISTRY".tls]
          insecure_skip_verify = true
    [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
EOF

# Restart containerd
echo "Restarting containerd..."
systemctl restart containerd

echo "Done! Containerd configured for insecure registry: $DOCKER_REGISTRY"
