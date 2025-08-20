output "alb_public_sg" {
  value = aws_security_group.alb_public_sg.id
}

output "bastion_sg" {
  value = aws_security_group.bastion_sg.id
}

output "web_sg" {
  value = aws_security_group.web_sg.id
}

output "alb_internal_sg" {
  value = aws_security_group.alb_internal_sg.id
}

output "app_sg" {
  value = aws_security_group.app_sg.id
}

output "db_sg" {
  value = aws_security_group.db_sg.id
}