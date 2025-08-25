```mermaid
flowchart LR
  Internet((Internet))

  subgraph Public_Subnet [Public Subnet]
    ALB_WEB[Public ALB :80 /health]
    Bastion[Bastion (SSH 22)]
    NATGW[NAT Gateway]
  end

  subgraph Private_App_Subnets [Private App Subnets]
    WEB_ASG[Web ASG (Nginx :80) /health=200 -> proxy :8080]
    ALB_APP[Internal ALB :8080 /index.jsp]
    APP_ASG[WAS ASG (Tomcat :8080)]
  end

  subgraph Private_DB_Subnets [Private DB Subnets]
    RDS[(RDS MySQL :3306)]
  end

  %% AI-OPS
  subgraph AI_OPS [AI-OPS (Inventory & Query)]
    DDB[(DynamoDB inventory table)]
    EB[EventBridge rule rate(10m)]
    L_COL[Lambda collector: EC2/ALB/TG/ASG/RDS]
    L_ASK[Lambda /ops handler]
  end

  %% 트래픽 경로
  Internet --> ALB_WEB
  ALB_WEB --> WEB_ASG
  WEB_ASG -->|proxy 8080| ALB_APP
  ALB_APP --> APP_ASG
  APP_ASG <-->|SQL 3306| RDS

  %% 사설 서브넷 아웃바운드
  WEB_ASG --> NATGW
  APP_ASG --> NATGW
  NATGW --> Internet

  %% Bastion
  Internet -->|admin_cidr| Bastion
  Bastion -. SSH .-> WEB_ASG
  Bastion -. SSH .-> APP_ASG
  Bastion -. MySQL .-> RDS

  %% /ops 경로 (내부 ALB 경유 → Lambda)
  ALB_APP -->|/ops*| L_ASK
  L_ASK --> DDB

  %% 수집 파이프라인
  EB --> L_COL --> DDB
```
