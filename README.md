# 3-Tier on AWS with Terraform

## 구성
```
ALB → EC2(Web, Nginx proxy) → Internal ALB → EC2(WAS, Tomcat) → RDS(MySQL)
bastion: 퍼블릭 서브넷/Web·Was·DB는 프라이빗 서브넷
리전: ap-northeast-1 (Tokyo)
```

## 프로젝트 구조
```

### root
- versions.tf — 프로젝트가 사용하는 Terraform/프로바이더 요구 버전을 명시해 실행 환경을 고정합니다.
- provider.tf — AWS 리전/프로필 등 Provider 연결 정보를 설정하며, 모든 모듈이 공통으로 사용합니다.
- variables.tf — 프로젝트에서 사용할 입력 변수를 선언합니다(값은 포함하지 않음).
- terraform.tfvars — 입력 변수의 실제 값을 채웁니다(민감정보는 비공개 권장).
- keys.tf — tls_private_key로 SSH 키 생성 → aws_key_pair로 AWS에 등록, 생성된 PEM을 로컬 저장합니다.
- main.tf — 하위 모듈들의 의존 순서와 연결을 정의합니다(앞 모듈 outputs → 뒤 모듈 inputs).
- outputs.tf — 배포 후 확인할 출력 값(web_alb_dns, app_alb_dns, db_endpoint, bastion_public_ip)을 정의합니다.

### modules
- modules/vpc/variables.tf — VPC, 서브넷 CIDR 등 네트워크 입력 값을 정의합니다.
- modules/vpc/main.tf — VPC / 퍼블릭·앱·DB 서브넷 / IGW / NAT(DEV 단일) / 라우팅을 생성합니다.
- modules/vpc/outputs.tf — vpc_id와 각 서브넷 ID를 출력합니다.

- modules/security/main.tf — 보안그룹(ALB 퍼블릭/내부, Web, App, DB, Bastion)과 인바운드/아웃바운드 규칙을 정의합니다.
- modules/security/outputs.tf — 각 보안그룹 ID를 출력합니다.

- modules/alb_web/main.tf — 퍼블릭 ALB:80, 타깃 그룹(헬스체크 /health), 리스너를 생성합니다.
  출력: ALB DNS, Web TG ARN

- modules/web/variables.tf — Web 모듈 입력(프라이빗 서브넷 IDs, SG ID, Web TG ARN, 내부 ALB DNS, 키페어)을 선언합니다.
- modules/web/main.tf — Nginx를 설치/설정하는 Launch Template, Auto Scaling Group을 생성합니다.
  - /health는 200 반환, 기본 경로는 내부 ALB:8080으로 리버스 프록시
  - Web TG에 등록, ASG 헬스체크/태그/롤링 갱신 설정 포함

- modules/alb_app/main.tf — 내부 ALB:8080, 타깃 그룹(헬스체크 /index.jsp), 리스너를 생성합니다.
  출력: 내부 ALB DNS, App TG ARN

- modules/app/variables.tf — App 모듈 입력(프라이빗 서브넷 IDs, SG ID, App TG ARN, RDS 엔드포인트, 키페어)을 선언합니다.
- modules/app/main.tf — Tomcat을 설치/기동하는 Launch Template, Auto Scaling Group을 생성합니다.
  - user_data에서 JDK 설치 + Tomcat(9.0.108) 배포 + systemd 등록
  - /opt/tomcat/webapps/ROOT/index.jsp 배포(페이지에 RDS 엔드포인트 등 표시)
  - App TG에 등록, ASG 헬스체크/태그/롤링 갱신 설정 포함

- modules/db/main.tf — DB Subnet Group과 RDS MySQL 8.0을 프라이빗 서브넷에 생성합니다(publicly_accessible=false).
- modules/db/outputs.tf — 애플리케이션 접속용 db_endpoint를 출력합니다.

- modules/bastion/main.tf — 퍼블릭 서브넷에 Bastion EC2를 생성하고, admin_cidr만 22/TCP 허용합니다.
  출력: Bastion Public IP


```

## 요약 다이어그램
```
[Internet] 
   ↓ 
[Public ALB :80] ──(GET /health)→ Web 인스턴스 로컬 200
   ↓ (proxy)
[Web ASG :80, Nginx] ──→ [Internal ALB :8080] ──(GET /index.jsp)→ [WAS ASG :8080, Tomcat]
                                                                  ↓
                                                               [RDS :3306]
```

## 사전 환경 구성
```
AWS CLI 설치 :
https://docs.aws.amazon.com/ko_kr/cli/v1/userguide/cli-chap-install.html
AWS CLI 자격 증명 인증 :
https://docs.aws.amazon.com/ko_kr/cli/v1/userguide/cli-authentication-user.html#cli-authentication-user-configure-wizard
Terraform 설치 :
https://developer.hashicorp.com/terraform/install
```

## 실행
```bash
terraform fmt -recursive
terraform init
terraform plan -out plan.tfplan
terraform apply "plan.tfplan"
```

## 옵션1. HTTPS + Route53
```
Route53 호스팅존 + ACM(갱신 리전) 발급 → Web ALB에 인증서 연결,
80→443 리다이렉트 A레코드(ALIAS)로 domain → web_alb_dns 매핑,
필요한 경우 modules/alb_web에 certificate_arn 변수/HTTPS 리스너 추가
```

## 옵션2. 시각화
```
https://graphviz.org/download/
```
