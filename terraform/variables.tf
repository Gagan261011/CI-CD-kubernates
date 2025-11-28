# ============================================
# VARIABLES.TF - Input Variables for DevOps Lab
# ============================================

# AWS Region Configuration
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the subnet"
  type        = string
  default     = "us-east-1a"
}

# EC2 Instance Configuration
variable "instance_type" {
  description = "EC2 instance type for all servers"
  type        = string
  default     = "t3.medium"
}

# Ubuntu 22.04 LTS AMI IDs by region
variable "ubuntu_ami" {
  description = "Ubuntu 22.04 LTS AMI ID (update based on your region)"
  type        = map(string)
  default = {
    "us-east-1"      = "ami-0c7217cdde317cfec"
    "us-east-2"      = "ami-05fb0b8c1424f266b"
    "us-west-1"      = "ami-0ce2cb35386fc22e9"
    "us-west-2"      = "ami-008fe2fc65df48dac"
    "eu-west-1"      = "ami-0905a3c97561e0b69"
    "eu-central-1"   = "ami-0faab6bdbac9486fb"
    "ap-south-1"     = "ami-03f4878755434977f"
    "ap-southeast-1" = "ami-078c1149d8ad719a7"
  }
}

# SSH Key Configuration
variable "key_name" {
  description = "Name of the SSH key pair to use for EC2 instances"
  type        = string
  default     = "devops-lab-key"
}

variable "create_key_pair" {
  description = "Whether to create a new key pair or use existing"
  type        = bool
  default     = true
}

# Project Tags
variable "project_name" {
  description = "Name of the project for tagging"
  type        = string
  default     = "devops-k8s-lab"
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "learning"
}

# Application Configuration
variable "app_port" {
  description = "Port on which the Spring Boot application will run"
  type        = number
  default     = 8080
}

variable "nexus_port" {
  description = "Port on which Nexus will run"
  type        = number
  default     = 8081
}

variable "nexus_docker_port" {
  description = "Port on which Nexus Docker registry will run"
  type        = number
  default     = 8082
}

variable "sonarqube_port" {
  description = "Port on which SonarQube will run"
  type        = number
  default     = 9000
}

variable "jenkins_port" {
  description = "Port on which Jenkins will run"
  type        = number
  default     = 8080
}

# Kubernetes Configuration
variable "k8s_pod_network_cidr" {
  description = "CIDR block for Kubernetes pod network"
  type        = string
  default     = "10.244.0.0/16"
}

# Common Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "DevOps-K8s-Lab"
    Environment = "Learning"
    ManagedBy   = "Terraform"
  }
}
