# ============================================
# OUTPUTS.TF - Output Values
# ============================================

# ==========================================
# VPC Outputs
# ==========================================
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.devops_lab_vpc.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public_subnet.id
}

# ==========================================
# Jenkins Outputs
# ==========================================
output "jenkins_public_ip" {
  description = "Public IP of Jenkins server"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_url" {
  description = "URL to access Jenkins"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

# ==========================================
# SonarQube Outputs
# ==========================================
output "sonarqube_public_ip" {
  description = "Public IP of SonarQube server"
  value       = aws_instance.sonarqube.public_ip
}

output "sonarqube_url" {
  description = "URL to access SonarQube"
  value       = "http://${aws_instance.sonarqube.public_ip}:9000"
}

# ==========================================
# Nexus Outputs
# ==========================================
output "nexus_public_ip" {
  description = "Public IP of Nexus server"
  value       = aws_instance.nexus.public_ip
}

output "nexus_url" {
  description = "URL to access Nexus"
  value       = "http://${aws_instance.nexus.public_ip}:8081"
}

output "nexus_docker_registry" {
  description = "Nexus Docker Registry URL"
  value       = "${aws_instance.nexus.public_ip}:8082"
}

# ==========================================
# Kubernetes Master Outputs
# ==========================================
output "k8s_master_public_ip" {
  description = "Public IP of Kubernetes Master"
  value       = aws_instance.k8s_master.public_ip
}

output "k8s_master_private_ip" {
  description = "Private IP of Kubernetes Master"
  value       = aws_instance.k8s_master.private_ip
}

# ==========================================
# Kubernetes Worker Outputs
# ==========================================
output "k8s_worker_1_public_ip" {
  description = "Public IP of Kubernetes Worker 1"
  value       = aws_instance.k8s_worker_1.public_ip
}

output "k8s_worker_2_public_ip" {
  description = "Public IP of Kubernetes Worker 2"
  value       = aws_instance.k8s_worker_2.public_ip
}

# ==========================================
# SSH Access Information
# ==========================================
output "ssh_key_file" {
  description = "Path to the SSH private key file"
  value       = var.create_key_pair ? "${path.module}/${var.key_name}.pem" : "Using existing key: ${var.key_name}"
}

output "ssh_commands" {
  description = "SSH commands to connect to each server"
  value = {
    jenkins      = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.jenkins.public_ip}"
    sonarqube    = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.sonarqube.public_ip}"
    nexus        = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.nexus.public_ip}"
    k8s_master   = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.k8s_master.public_ip}"
    k8s_worker_1 = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.k8s_worker_1.public_ip}"
    k8s_worker_2 = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.k8s_worker_2.public_ip}"
  }
}

# ==========================================
# Post-Deployment Instructions
# ==========================================
output "post_deployment_steps" {
  description = "Commands to run after deployment"
  value = <<-EOT
    
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                  POST-DEPLOYMENT CONFIGURATION STEPS                         ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║                                                                              ║
    ║  1. JOIN KUBERNETES WORKERS TO CLUSTER:                                     ║
    ║     ----------------------------------------                                 ║
    ║     # SSH to K8s Master and get join command:                               ║
    ║     ssh -i ${var.key_name}.pem ubuntu@${aws_instance.k8s_master.public_ip}
    ║     cat /home/ubuntu/join-command.sh                                         ║
    ║                                                                              ║
    ║     # SSH to each worker and run the join command:                          ║
    ║     ssh -i ${var.key_name}.pem ubuntu@${aws_instance.k8s_worker_1.public_ip}
    ║     sudo [paste-join-command-here]                                           ║
    ║                                                                              ║
    ║     ssh -i ${var.key_name}.pem ubuntu@${aws_instance.k8s_worker_2.public_ip}
    ║     sudo [paste-join-command-here]                                           ║
    ║                                                                              ║
    ║  2. CONFIGURE KUBECTL ON JENKINS:                                            ║
    ║     ----------------------------------------                                 ║
    ║     ssh -i ${var.key_name}.pem ubuntu@${aws_instance.jenkins.public_ip}
    ║     /home/ubuntu/fetch-kubeconfig.sh ${aws_instance.k8s_master.public_ip}   ║
    ║                                                                              ║
    ║  3. GET JENKINS INITIAL PASSWORD:                                            ║
    ║     ----------------------------------------                                 ║
    ║     ssh -i ${var.key_name}.pem ubuntu@${aws_instance.jenkins.public_ip}
    ║     cat /home/ubuntu/jenkins_initial_password.txt                            ║
    ║                                                                              ║
    ║  4. CONFIGURE NEXUS DOCKER REGISTRY:                                         ║
    ║     ----------------------------------------                                 ║
    ║     - Login to Nexus: http://${aws_instance.nexus.public_ip}:8081           ║
    ║     - Get password: ssh -i ${var.key_name}.pem ubuntu@${aws_instance.nexus.public_ip}
    ║       cat /home/ubuntu/nexus_admin_password.txt                              ║
    ║     - Follow instructions in: /home/ubuntu/configure-nexus-docker.sh        ║
    ║                                                                              ║
    ║  5. CONFIGURE SONARQUBE TOKEN:                                               ║
    ║     ----------------------------------------                                 ║
    ║     - Login to SonarQube: http://${aws_instance.sonarqube.public_ip}:9000   ║
    ║     - Default credentials: admin / admin                                     ║
    ║     - Generate token: Account > Security > Generate Token                    ║
    ║                                                                              ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

  EOT
}

# ==========================================
# Quick Reference Summary
# ==========================================
output "summary" {
  description = "Quick reference summary of all resources"
  value = <<-EOT
    
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                      DEVOPS KUBERNETES LAB SUMMARY                           ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║                                                                              ║
    ║  JENKINS                                                                     ║
    ║    URL:  http://${aws_instance.jenkins.public_ip}:8080                      ║
    ║    SSH:  ssh -i ${var.key_name}.pem ubuntu@${aws_instance.jenkins.public_ip}
    ║                                                                              ║
    ║  SONARQUBE                                                                   ║
    ║    URL:  http://${aws_instance.sonarqube.public_ip}:9000                    ║
    ║    Cred: admin / admin                                                       ║
    ║    SSH:  ssh -i ${var.key_name}.pem ubuntu@${aws_instance.sonarqube.public_ip}
    ║                                                                              ║
    ║  NEXUS                                                                       ║
    ║    URL:  http://${aws_instance.nexus.public_ip}:8081                        ║
    ║    Docker: ${aws_instance.nexus.public_ip}:8082                             ║
    ║    SSH:  ssh -i ${var.key_name}.pem ubuntu@${aws_instance.nexus.public_ip}
    ║                                                                              ║
    ║  KUBERNETES CLUSTER                                                          ║
    ║    Master:   ${aws_instance.k8s_master.public_ip}                           ║
    ║    Worker 1: ${aws_instance.k8s_worker_1.public_ip}                         ║
    ║    Worker 2: ${aws_instance.k8s_worker_2.public_ip}                         ║
    ║                                                                              ║
    ║  SSH KEY: ${var.key_name}.pem                                                ║
    ║                                                                              ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

  EOT
}
