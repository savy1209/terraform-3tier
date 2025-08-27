# 3-Tier on AWS with Terraform

## 구성
```
ALB → EC2(Web, Nginx proxy) → Internal ALB → EC2(WAS, Tomcat) → RDS(MySQL)
bastion: 퍼블릭 서브넷/Web·Was·DB는 프라이빗 서브넷
리전: ap-northeast-1 (Tokyo)
```

## 프로젝트 구조
```

root

- `versions.tf` — Terraform/Provider **버전 고정**(재현성 확보)
- `provider.tf` — AWS Provider **연결 설정**(리전/프로필 등)
- `variables.tf` — 루트 **입력 변수 선언**(region, project, admin_cidr, DB 등)
- `terraform.tfvars` — 변수 **실제 값** 넣는 로컬 파일(비공개 권장)
- `keys.tf` — `tls_private_key`→`aws_key_pair`로 **키 생성/등록**, PEM 로컬 저장
- `main.tf` — 하위 모듈 **배선**(앞 모듈 outputs → 뒤 모듈 inputs)
- `outputs.tf` — 배포 후 확인용 **출력 값** 정의(web_alb_dns, db_endpoint 등)

modules

- `modules/vpc/variables.tf` — VPC/서브넷/AZ 등 **네트워크 입력 변수**
- `modules/vpc/main.tf` — **VPC·서브넷(공/앱/DB)·IGW·NAT(DEV 단일)·라우팅** 생성
- `modules/vpc/outputs.tf` — `vpc_id`, **서브넷 IDs** 출력
- `modules/security/main.tf` — **보안그룹 세트**(ALB(pub/inner), Web, App, DB, Bastion)
- `modules/security/outputs.tf` — 각 **SG ID 출력**
- `modules/alb_web/main.tf` — **퍼블릭 ALB:80** + TG(`/health`) + 리스너
- `modules/web/variables.tf` — Web 모듈 **입력 변수**(서브넷, SG, TG ARN, 백엔드 ALB DNS, 키)
- `modules/web/main.tf` — **Nginx 프록시 ASG**(헬스 `/health`, 내부 ALB:8080으로 프록시) + TG 연결
- `modules/alb_app/main.tf` — **내부 ALB:8080** + TG(`/index.jsp`) + 리스너
- `modules/app/variables.tf` — App 모듈 **입력 변수**(서브넷, SG, TG ARN, RDS 엔드포인트, 키)
- `modules/app/main.tf` — **Tomcat ASG**(user_data로 JDK+wget 설치/기동, `/index.jsp`) + TG 연결
- `modules/db/main.tf` — **DB Subnet Group + RDS MySQL**(프라이빗, 퍼블릭 비공개)
- `modules/db/outputs.tf` — **`db_endpoint`** 출력
- `modules/bastion/main.tf` — **Bastion EC2**(퍼블릭 서브넷, 22는 `admin_cidr`만 허용)

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
