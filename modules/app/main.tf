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
    set -euxo pipefail

    # 0) wget 설치 (필요시)
    dnf install -y wget

    # 1) JDK 설치 (17 우선, 없으면 21 폴백) — user_data는 root로 실행
    dnf install -y java-17-amazon-corretto || dnf install -y java-21-amazon-corretto

    # 2) Tomcat 바이너리 설치 (9.0.108)
    id tomcat || useradd -r -m -d /opt/tomcat -s /sbin/nologin tomcat
    mkdir -p /opt/tomcat
    wget -q -O /tmp/tomcat.tar.gz "https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.108/bin/apache-tomcat-9.0.108.tar.gz"
    tar -xzf /tmp/tomcat.tar.gz -C /opt/tomcat --strip-components=1
    chown -R tomcat:tomcat /opt/tomcat
    chmod +x /opt/tomcat/bin/*.sh

    # 3) systemd 유닛 (JAVA_HOME 지정 없이 PATH의 java 사용)
    cat >/etc/systemd/system/tomcat.service <<'UNIT'
    [Unit]
    Description=Apache Tomcat 9
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=forking
    User=tomcat
    Group=tomcat
    Environment=CATALINA_HOME=/opt/tomcat
    Environment=CATALINA_BASE=/opt/tomcat
    ExecStart=/opt/tomcat/bin/startup.sh
    ExecStop=/opt/tomcat/bin/shutdown.sh
    Restart=on-failure
    SuccessExitStatus=143

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable --now tomcat

    # 4) 앱 설정 (RDS 엔드포인트)
    mkdir -p /etc/myapp
    cat >/etc/myapp/app.properties <<'PROPS'
    db.endpoint=${var.rds_endpoint}
    db.user=APPUSER
    db.name=appdb
    PROPS

    # 5) 헬스체크 대상 페이지 (App TG: /index.jsp)
    WEBROOT="/opt/tomcat/webapps/ROOT"
    mkdir -p "$WEBROOT"
    cat >"$WEBROOT/index.jsp" <<'JSP'
    <%@ page import="java.util.*,java.io.*" %>
    <%
      Properties p = new Properties();
      try (FileInputStream in = new FileInputStream("/etc/myapp/app.properties")) { p.load(in); }
      out.println("<h1>Hello from WAS (Tomcat)</h1>");
      out.println("<p>RDS endpoint: " + p.getProperty("db.endpoint") + "</p>");
      out.println("<p>DB user: " + p.getProperty("db.user") + "</p>");
      out.println("<p>DB name: " + p.getProperty("db.name") + "</p>");
    %>
    JSP
    chown -R tomcat:tomcat "$WEBROOT"
    chmod -R a+r "$WEBROOT"

    systemctl restart tomcat
  EOT
}

resource "aws_launch_template" "lt" {
  name_prefix            = "${var.project}-app-"
  image_id               = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [var.security_group_id]
  user_data              = base64encode(local.user_data)
  key_name               = var.key_name
}

resource "aws_autoscaling_group" "asg" {
  name                = "${var.project}-app-asg"
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
    value               = "${var.project}-was"
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }
  tag {
    key                 = "Role"
    value               = "was"
    propagate_at_launch = true
  }

  # LT 변경 시 롤링 교체
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}