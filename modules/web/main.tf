data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

locals {
  user_data = <<-EOT
    #!/bin/bash
    dnf install -y nginx
    cat >/etc/nginx/nginx.conf <<'NGINX'
    user nginx; worker_processes auto; error_log /var/log/nginx/error.log; pid /run/nginx.pid;
    events { worker_connections 1024; }
    http {
      include /etc/nginx/mime.types; default_type application/octet-stream;
      access_log /var/log/nginx/access.log; sendfile on; keepalive_timeout 65;

      # App ALB로 프록시
      upstream app_upstream { server ${var.backend_alb_dns}:8080; }

      server {
        listen 80;

        # 헬스체크 전용 로컬 엔드포인트
        location = /health {
          return 200 'ok';
          add_header Content-Type text/plain;
        }

        location / {
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_pass http://app_upstream;
        }
      }
    }
    NGINX
    systemctl enable --now nginx
  EOT
}

resource "aws_launch_template" "lt" {
  name_prefix            = "${var.project}-web-"
  image_id               = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [var.security_group_id]
  user_data              = base64encode(local.user_data)
  key_name               = var.key_name
}

resource "aws_autoscaling_group" "asg" {
  name                = "${var.project}-web-asg"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  # 태그 전파 (콘솔 Name 표기)
  tag {
    key                 = "Name"
    value               = "${var.project}-web"
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }
  tag {
    key                 = "Role"
    value               = "web"
    propagate_at_launch = true
  }

  # 롤링 인스턴스 새로고침
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}