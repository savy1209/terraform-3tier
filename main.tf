module "vpc" {
  source   = "./modules/vpc"
  project  = var.project
  cidr_vpc = var.cidr_vpc
  az_count = var.az_count
}

module "security" {
  source     = "./modules/security"
  vpc_id     = module.vpc.vpc_id
  admin_cidr = var.admin_cidr
}

module "alb_app" {
  source             = "./modules/alb_app"
  project            = var.project
  private_subnet_ids = module.vpc.private_app_subnet_ids
  security_group_id  = module.security.alb_internal_sg
  vpc_id             = module.vpc.vpc_id
}

module "app" {
  source             = "./modules/app"
  project            = var.project
  private_subnet_ids = module.vpc.private_app_subnet_ids
  security_group_id  = module.security.app_sg
  target_group_arn   = module.alb_app.target_group_arn
  rds_endpoint       = module.db.db_endpoint
  key_name           = aws_key_pair.project.key_name
}

module "alb_web" {
  source            = "./modules/alb_web"
  project           = var.project
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.security.alb_public_sg
  vpc_id            = module.vpc.vpc_id
}

module "web" {
  source             = "./modules/web"
  project            = var.project
  private_subnet_ids = module.vpc.private_app_subnet_ids
  security_group_id  = module.security.web_sg
  target_group_arn   = module.alb_web.target_group_arn
  backend_alb_dns    = module.alb_app.alb_dns
  key_name           = aws_key_pair.project.key_name
}

module "bastion" {
  source            = "./modules/bastion"
  project           = var.project
  public_subnet_id  = module.vpc.public_subnet_ids[0]
  security_group_id = module.security.bastion_sg
  key_name          = aws_key_pair.project.key_name
}

module "db" {
  source            = "./modules/db"
  project           = var.project
  db_subnet_ids     = module.vpc.private_db_subnet_ids
  security_group_id = module.security.db_sg
  db_user           = var.db_user
  db_password       = var.db_password
}