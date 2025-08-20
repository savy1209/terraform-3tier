variable "project" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "rds_endpoint" {
  type = string
}

variable "key_name" {
  type = string
}