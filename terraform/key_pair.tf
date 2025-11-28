# ============================================
# KEY_PAIR.TF - SSH Key Pair for EC2 Access
# ============================================

# Generate a new TLS private key
resource "tls_private_key" "devops_lab_key" {
  count     = var.create_key_pair ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS Key Pair from the generated key
resource "aws_key_pair" "devops_lab_key" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.key_name
  public_key = tls_private_key.devops_lab_key[0].public_key_openssh

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-key-pair"
  })
}

# Save the private key locally for SSH access
resource "local_file" "private_key" {
  count           = var.create_key_pair ? 1 : 0
  content         = tls_private_key.devops_lab_key[0].private_key_pem
  filename        = "${path.module}/${var.key_name}.pem"
  file_permission = "0400"
}
