flowchart LR
  Internet[(Internet)]
  subgraph Public_Subnet["Public Subnet"]
    ALB_WEB[Public ALB :80<br/>/health]
    Bastion[Bastion (SSH 22)]
    NAT[NAT Gateway]
  end

  subgraph Private_App_Subnets["Private App Subnets"]
    WEB_ASG[Web ASG (Nginx :80)<br/>/health=200 → proxy to :8080]
    ALB_APP[Internal ALB :8080<br/>/index.jsp]
    APP_ASG[WAS ASG (Tomcat :8080)]
  end

  subgraph Private_DB_Subnets["Private DB Subnets"]
    RDS[(RDS MySQL :3306<br/>publicly_accessible=false)]
  end

  %% AI-OPS
  subgraph AI_OPS["AI-OPS (인벤토리 & 질의)"]
    DDB[(DynamoDB<br/>inventory table)]
    EB[EventBridge rule<br/>rate(10m)]
    L_COL[Lambda collector<br/>EC2/ALB/TG/ASG/RDS 수집]
    L_ASK[Lambda /ops handler<br/>검색/요약(JSON)]
  end

  %% 트래픽 경로
  Internet --> ALB_WEB
  ALB_WEB --> WEB_ASG
  WEB_ASG -->|proxy :8080| ALB_APP
  ALB_APP --> APP_ASG
  APP_ASG <--> RDS

  %% 사설 서브넷 아웃바운드
  WEB_ASG --> NAT
  APP_ASG --> NAT
  NAT --> Internet

  %% Bastion
  Internet -->|admin_cidr| Bastion
  Bastion -. SSH -.-> WEB_ASG
  Bastion -. SSH -.-> APP_ASG
  Bastion -. MySQL -.-> RDS

  %% /ops 경로 (내부 ALB 경유 → Lambda)
  ALB_APP -->|path: /ops*| L_ASK
  L_ASK --> DDB

  %% 수집 파이프라인
  EB --> L_COL --> DDB
