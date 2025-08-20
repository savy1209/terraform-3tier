variable "project" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "vpc_id" { type = string }

resource "aws_lb" "web" {
  name               = "${var.project}-web-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [var.security_group_id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "web_tg" {
  name     = "${var.project}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # 헬스체크를 NGINX 로컬 엔드포인트(/health)로 분리
  health_check {
    path                = "/health"
    protocol            = "HTTP"
    port                = "80"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

output "alb_dns" { value = aws_lb.web.dns_name }
output "target_group_arn" { value = aws_lb_target_group.web_tg.arn }