[3-Tier on AWS with Terraform]

ALB → EC2(Web, Nginx proxy) → Internal ALB → EC2(WAS, Tomcat) ↔ RDS(MySQL)
Bastion(host) in public subnet for SSH. Web/WAS in private subnets. Region: ap-northeast-1

[프로젝트 구조]

dev-three-tier/              · 루트(여기서 terraform 실행). 전체 리소스 연결, 변수/출력 관리
├─ versions.tf               · Terraform/AWS Provider 버전 고정(재현성)
├─ provider.tf               · AWS Provider 설정(리전, 프로필)
├─ variables.tf              · 루트 입력 변수 선언(리전, 프로젝트명, admin_cidr, DB 계정 등)
├─ keys.tf                   · 키페어 자동 생성(tls → aws_key_pair), 로컬 .pem 저장(0600)
├─ main.tf                   · 모듈 연결: VPC → SG → ALB(외부/내부) → EC2(Web/WAS) → RDS + Bastion
├─ outputs.tf                · `terraform output` 항목(web_alb_dns, app_alb_dns, db_endpoint, bastion_ip 등)
├─ terraform.tfvars          · 환경별 값(DEV용 기본값, 민감정보는 여기서 주입)
└─ modules/                  · 기능별 하위 모듈 모음
   ├─ vpc/                   · 네트워크 기본틀
   │  ├─ variables.tf        · VPC/서브넷 크기, AZ 수 등 입력값
   │  ├─ main.tf             · VPC, 인터넷 게이트웨이(IGW), NAT 게이트웨이(DEV: 1개),
   │  │                       · 서브넷 3종:
   │  │                          - 퍼블릭 서브넷: 인터넷에서 바로 접근 가능(ALB, Bastion, NAT 위치)
   │  │                          - 앱 서브넷(프라이빗): 인터넷에 직접 노출 안 됨(Web/WAS, 내부 ALB 위치)
   │  │                          - DB 서브넷(프라이빗): RDS 전용
   │  │                       · 라우팅: 퍼블릭 → IGW / 앱·DB → NAT(아웃바운드용)
   │  └─ outputs.tf          · vpc_id, 각 서브넷 IDs(퍼블릭/앱/DB) 출력
   │
   ├─ security/              · 보안그룹(인바운드 경로 정의)
   │  ├─ main.tf             · ALB(외부 80), Bastion(22), Web(80), ALB(내부 8080), App(8080), DB(3306)
   │  └─ outputs.tf          · SG ID들 출력(다른 모듈에서 참조)
   │
   ├─ alb_web/               · 외부 진입점(클라이언트 → 여기로)
   │  └─ main.tf             · 퍼블릭 ALB(HTTP:80), 타깃그룹(헬스체크 `/health`), 리스너
   │                         · (원하면 HTTPS로 확장 가능: 80→443 리다이렉트/ACM)
   │                         · 출력: `alb_dns`, `target_group_arn`(필요 시 `alb_zone_id`)
   │
   ├─ web/                   · 웹 계층(Nginx 리버스 프록시, 프라이빗 서브넷)
   │  ├─ variables.tf        · LT/ASG 입력(서브넷IDs, SG ID, TG ARN, 키페어, 백엔드 ALB DNS 등)
   │  └─ main.tf             · Launch Template(user_data로 Nginx 설치/설정)
   │                         · Auto Scaling Group(태그 전파로 EC2 Name 표시, 헬스 유예 300초, 롤링 교체)
   │                         · Nginx: `/health`는 로컬 200, 나머진 내부 ALB:8080으로 프록시
   │
   ├─ alb_app/               · 내부 로드밸런서(웹 → WAS 분산)
   │  └─ main.tf             · 내부 ALB(8080), 타깃그룹(헬스 `/index.jsp`), 리스너
   │                         · 출력: `alb_dns`, `target_group_arn`
   │
   ├─ app/                   · WAS 계층(Tomcat, 프라이빗 서브넷)
   │  └─ main.tf             · Launch Template(user_data에서 JDK 설치 + wget으로 Tomcat 9.0.108 설치)
   │                         · systemd 유닛 등록, `/opt/tomcat/webapps/ROOT/index.jsp` 배포
   │                         · Auto Scaling Group(헬스 유예 300초, 롤링 교체)
   │
   ├─ db/                    · 데이터 계층(RDS MySQL 8.0)
   │  ├─ main.tf             · DB Subnet Group(프라이빗-DB), RDS 인스턴스(DEV 기본 Multi-AZ=true)
   │  └─ outputs.tf          · `db_endpoint` 출력(앱 user_data에 주입 → 페이지에서 보임)
   │
   └─ bastion/               · 점프호스트(퍼블릭 서브넷, SSH용)
      └─ main.tf             · 단일 EC2, `admin_cidr`에서만 22 허용 → 내부 Web/WAS로 접속





[요약]
[Internet] 
   ↓ 
[Public ALB :80] ──(GET /health)→ Web 인스턴스 로컬 200
   ↓ (proxy)
[Web ASG :80, Nginx] ──→ [Internal ALB :8080] ──(GET /index.jsp)→ [WAS ASG :8080, Tomcat]
                                                                  ↓
                                                               [RDS :3306]