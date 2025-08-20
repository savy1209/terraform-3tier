variable "project" {
  type = string
}

variable "db_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

resource "aws_db_subnet_group" "subnets" {
  name       = "${var.project}-db-subnet"
  subnet_ids = var.db_subnet_ids
}

resource "aws_db_instance" "mysql" {
  identifier             = "${var.project}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.subnets.name
  vpc_security_group_ids = [var.security_group_id]
  username               = var.db_user
  password               = var.db_password
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = true
}