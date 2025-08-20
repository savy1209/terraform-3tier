# 3-Tier on AWS with Terraform

## 구성
ALB → EC2(Web, Nginx proxy) → Internal ALB → EC2(WAS, Tomcat) → RDS(MySQL) bastion: 퍼블릭 서브넷/  
Web·Was·DB는 프라이빗 서브넷 리전: ap-northeast-1 (Tokyo)

## 프로젝트 구조
```
dev-three-tier/
├── versions.tf         # Terraform/AWS Provider 버전 고정(제한성)
├── provider.tf         # AWS Provider 설정(리전, 프로필)
├── variables.tf        # 루트 입력 변수 선언(리전, 프로젝트명, admin_cidr, DB 계정 등)
├── keys.tf             # 키페어 자동 생성(tls → aws_key_pair), 로컬 .pem 저장(0600)
├── main.tf             # 모듈 연결: VPC → SG → ALB(외부/내부) → EC2(Web/WAS) → RDS + Bastion
├── outputs.tf          # terraform output 정목(web_alb_dns, app_alb_dns, db_endpoint, bastion_ip 등)
├── terraform.tfvars    # 환경별 값(DEV용 기본값, 민감정보는 여기서 주입)
└── modules/            # 기능별 하위 모듈 모음
    ├── vpc/            # 네트워크 기본틀
    │   ├── variables.tf # VPC/서브넷 크기, AZ 수 등 입력값
    │   └── main.tf     # VPC, IGW, NAT GW(DEV: 1개), 서브넷 3종
    ├── security/       # 보안그룹(인바운드 경로 정의)
    │   ├── alb_web/    # 외부 ALB(HTTP:80, TG /health) HTTPS 확장 가능
    │   ├── web/        # Nginx 프록시 ASG(프라이빗) — /health 200, 나머지 내부 ALB:8080 프록시
    │   ├── alb_app/    # 내부 ALB(8080, TG /index.jsp)
    │   ├── app/        # Tomcat ASG(프라이빗, JDK+wget 바이너리 설치, /index.jsp)
    │   ├── db/         # RDS MySQL 8.0(+Subnet Group)
    │   └── bastion/    # 점프호스트(퍼블릭, SSH; admin_cidr 제한)
```

## 요약 다이어그램
**[Internet]** ↓ **[Public ALB :80]** —(GET /health)→ **Web 인스턴스 로컬 200** ! (proxy) **[Web ASG :80, Nginx]** ——→ **[Internal ALB :8080]** —(GET /index.jsp)→ **[WAS ASG :8080, Tomcat]** ↓ **[RDS :3306]**

## 사전 환경 구성
AWS CLI 설치 : https://docs.aws.amazon.com/ko_kr/cli/v1/userguide/cli-chap-install.html  
AWS CLI 자격 증명 인증 : https://docs.aws.amazon.com/ko_kr/cli/v1/userguide/cli-authentication-user.html#cli-authentication-user-configure-wizard  
Terraform 설치 : https://developer.hashicorp.com/terraform/install

## 실행
```bash
terraform fmt -recursive
terraform init
terraform plan -out plan.tfplan
terraform apply "plan.tfplan"
```

## 옵션1. HTTPS + Route53
Route53 호스팅존 + ACM(갱신 리전) 발급 → Web ALB에 인증서 연결, 80→443 리다이렉트 A레코드(ALIAS)로 domain → web_alb_dns 매핑, 필요한 경우 modules/alb_web에 certificate_arn 변수/HTTPS 리스너 추가

## 옵션2. 시각화
https://graphviz.org/download/
