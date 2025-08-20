variable "project" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "vpc_id" { type = string }

resource "aws_lb" "app" {
  name               = "${var.project}-app-alb"
  load_balancer_type = "application"
  internal           = true
  security_groups    = [var.security_group_id]
  subnets            = var.private_subnet_ids
}

resource "aws_lb_target_group" "app_tg" {
  name     = "${var.project}-app-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Tomcat이 제공하는 실제 페이지로 헬스체크
  health_check {
    path                = "/index.jsp"
    protocol            = "HTTP"
    port                = "8080"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

output "alb_dns" { value = aws_lb.app.dns_name }
output "target_group_arn" { value = aws_lb_target_group.app_tg.arn }