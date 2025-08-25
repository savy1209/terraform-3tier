```mermaid
flowchart LR
  Internet((Internet))

  subgraph Public_Subnet["Public Subnet"]
    ALB_WEB[Public ALB :80]
    Bastion[Bastion (SSH 22)]
    NATGW[NAT Gateway]
  end

  subgraph Private_App["Private App Subnets"]
    WEB_ASG[Web ASG (Nginx :80)]
    ALB_APP[Internal ALB :8080]
    APP_ASG[WAS ASG (Tomcat :8080)]
  end

  subgraph Private_DB["Private DB Subnets"]
    RDS[(RDS MySQL :3306)]
  end

  subgraph AI_OPS["AI-OPS (Inventory/Activity)"]
    DDB[(DynamoDB)]
    EB[EventBridge 10m]
    L_COL[Lambda collector]
    L_OPS[Lambda /ops]
    L_ACT[Lambda /ops/activity]
  end

  %% 트래픽 경로
  Internet --> ALB_WEB
  ALB_WEB --> WEB_ASG
  WEB_ASG -->|proxy 8080| ALB_APP
  ALB_APP --> APP_ASG
  APP_ASG -->|MySQL 3306| RDS

  %% 사설 서브넷 아웃바운드
  WEB_ASG --> NATGW
  APP_ASG --> NATGW
  NATGW --> Internet

  %% Bastion
  Internet -->|admin_cidr| Bastion
  Bastion -.-> WEB_ASG
  Bastion -.-> APP_ASG
  Bastion -.-> RDS

  %% AI-OPS 라우팅/수집
  ALB_APP -->|/ops| L_OPS
  ALB_APP -->|/ops/activity| L_ACT
  L_OPS --> DDB
  L_ACT --> DDB
  EB --> L_COL --> DDB
```
