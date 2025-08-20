output "web_alb_dns" {
  value = module.alb_web.alb_dns
}

output "app_alb_dns" {
  value = module.alb_app.alb_dns
}

output "db_endpoint" {
  value = module.db.db_endpoint
}

output "bastion_public_ip" {
  value = module.bastion.public_ip
}