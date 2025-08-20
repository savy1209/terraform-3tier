variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "aws_profile" {
  type    = string
  default = null
}

variable "project" {
  type    = string
  default = "dev-three-tier"
}

variable "cidr_vpc" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

# DB
variable "db_user" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

# SSH/Bastion
variable "admin_cidr" {
  type    = string
  default = "사무실 IP 대역 기입"
}
