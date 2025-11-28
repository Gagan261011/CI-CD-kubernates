# ============================================
# EC2.TF - EC2 Instances for All Servers
# ============================================

# ==========================================
# JENKINS SERVER
# ==========================================
resource "aws_instance" "jenkins" {
  ami                    = var.ubuntu_ami[var.aws_region]
  instance_type          = var.instance_type
  key_name               = var.create_key_pair ? aws_key_pair.devops_lab_key[0].key_name : var.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  user_data = templatefile("${path.module}/scripts/jenkins_userdata.sh", {
    key_path = var.key_name
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-jenkins"
    Role = "Jenkins"
  })
}

# ==========================================
# SONARQUBE SERVER
# ==========================================
resource "aws_instance" "sonarqube" {
  ami                    = var.ubuntu_ami[var.aws_region]
  instance_type          = var.instance_type
  key_name               = var.create_key_pair ? aws_key_pair.devops_lab_key[0].key_name : var.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.sonarqube_sg.id]

  user_data = file("${path.module}/scripts/sonarqube_userdata.sh")

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-sonarqube"
    Role = "SonarQube"
  })
}

# ==========================================
# NEXUS SERVER
# ==========================================
resource "aws_instance" "nexus" {
  ami                    = var.ubuntu_ami[var.aws_region]
  instance_type          = var.instance_type
  key_name               = var.create_key_pair ? aws_key_pair.devops_lab_key[0].key_name : var.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.nexus_sg.id]

  user_data = file("${path.module}/scripts/nexus_userdata.sh")

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-nexus"
    Role = "Nexus"
  })
}

# ==========================================
# KUBERNETES MASTER NODE
# ==========================================
resource "aws_instance" "k8s_master" {
  ami                    = var.ubuntu_ami[var.aws_region]
  instance_type          = var.instance_type
  key_name               = var.create_key_pair ? aws_key_pair.devops_lab_key[0].key_name : var.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.k8s_master_sg.id]

  user_data = templatefile("${path.module}/scripts/k8s_master_userdata.sh", {
    pod_network_cidr = var.k8s_pod_network_cidr
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-k8s-master"
    Role = "K8sMaster"
    "kubernetes.io/cluster/${var.project_name}" = "owned"
  })
}

# ==========================================
# KUBERNETES WORKER NODE 1
# ==========================================
resource "aws_instance" "k8s_worker_1" {
  ami                    = var.ubuntu_ami[var.aws_region]
  instance_type          = var.instance_type
  key_name               = var.create_key_pair ? aws_key_pair.devops_lab_key[0].key_name : var.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.k8s_worker_sg.id]

  # User data will include join command - needs to wait for master
  user_data = templatefile("${path.module}/scripts/k8s_worker_userdata.sh", {
    join_command = "# Join command will be executed manually or via script"
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-k8s-worker-1"
    Role = "K8sWorker"
    "kubernetes.io/cluster/${var.project_name}" = "owned"
  })

  depends_on = [aws_instance.k8s_master]
}

# ==========================================
# KUBERNETES WORKER NODE 2
# ==========================================
resource "aws_instance" "k8s_worker_2" {
  ami                    = var.ubuntu_ami[var.aws_region]
  instance_type          = var.instance_type
  key_name               = var.create_key_pair ? aws_key_pair.devops_lab_key[0].key_name : var.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.k8s_worker_sg.id]

  # User data will include join command - needs to wait for master
  user_data = templatefile("${path.module}/scripts/k8s_worker_userdata.sh", {
    join_command = "# Join command will be executed manually or via script"
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-k8s-worker-2"
    Role = "K8sWorker"
    "kubernetes.io/cluster/${var.project_name}" = "owned"
  })

  depends_on = [aws_instance.k8s_master]
}
