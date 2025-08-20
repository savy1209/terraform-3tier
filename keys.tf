resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "private_key_pem" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/${var.project}-tokyo-key.pem"
  file_permission = "0600"
}

resource "aws_key_pair" "project" {
  key_name   = "${var.project}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

output "ssh_private_key_path" {
  value     = local_sensitive_file.private_key_pem.filename
  sensitive = true
}

output "ssh_keypair_name" {
  value = aws_key_pair.project.key_name
}