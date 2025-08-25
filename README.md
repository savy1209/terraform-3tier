flowchart LR
  Internet

  subgraph Public_Subnet
    ALB_WEB[Public ALB 80 health]
    Bastion[Bastion SSH 22]
    NATGW[NAT Gateway]
  end

  subgraph Private_App_Subnets
    WEB_ASG[Web ASG Nginx 80]
    ALB_APP[Internal ALB 8080]
    APP_ASG[WAS ASG Tomcat 8080]
  end

  subgraph Private_DB_Subnets
    RDS[RDS MySQL 3306 private]
  end

  subgraph AI_OPS
    DDB[DynamoDB inventory]
    EB[EventBridge rule 10m]
    L_COL[Lambda collector]
    L_ASK[Lambda ops handler]
  end

  %% 트래픽 경로
  Internet --> ALB_WEB
  ALB_WEB --> WEB_ASG
  WEB_ASG --> ALB_APP
  ALB_APP --> APP_ASG
  APP_ASG --> RDS

  %% 사설 서브넷 아웃바운드
  WEB_ASG --> NATGW
  APP_ASG --> NATGW
  NATGW --> Internet

  %% Bastion 경로
  Internet --> Bastion
  Bastion --> WEB_ASG
  Bastion --> APP_ASG
  Bastion --> RDS

  %% /ops 경로 (내부 ALB 경유 Lambda)
  ALB_APP --> L_ASK
  L_ASK --> DDB

  %% 수집 파이프라인
  EB --> L_COL
  L_COL --> DDB
