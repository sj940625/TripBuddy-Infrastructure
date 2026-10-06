# ☁️ TripBuddy Infrastructure

> **TripBuddy 팀 프로젝트에서 담당한 AWS 인프라 설계·구축, Terraform IaC, EKS 운영 환경 및 CI/CD 구성을 정리한 포트폴리오 저장소입니다.**

TripBuddy는 여행지, 일정, 인원, 예산과 취향을 입력하면 AI가 여행 일정을 생성하고 지도 동선과 예상 경비를 제공하는 여행 플래너입니다.

이 저장소는 애플리케이션 전체 코드가 아니라, 제가 담당한 **Cloud Infrastructure / DevOps 영역**을 중심으로 정리했습니다.

---

## 📌 Project Info

| 구분 | 내용 |
|---|---|
| 프로젝트 | TripBuddy |
| 담당 역할 | AWS Infrastructure / DevOps |
| Cloud | AWS (VPC, EKS, RDS, S3, CloudFront, SQS, ECR) |
| IaC | Terraform |
| Container | Docker / Kubernetes / Amazon EKS |
| CI/CD | Jenkins / GitHub Actions |
| Database | Amazon RDS for MariaDB |
| Cache | Amazon ElastiCache for Redis |
| Messaging | Amazon SQS / DLQ |
| AI | Amazon Bedrock |

---

## 🏗 System Architecture

<p align="center">
  <img src="docs/images/architecture.png" alt="TripBuddy Infrastructure Architecture" width="1000"/>
</p>

### 요청 흐름

- **정적 콘텐츠**: `User → CloudFront → S3`
- **일반 API**: `User → CloudFront → VPC Origin → Internal ALB → EKS API Pod`
- **AI 일정 생성**: `API Pod → SQS → Worker Pod → Amazon Bedrock`
- **데이터 계층**: `API Pod → RDS / Redis`
- **컨테이너 이미지 배포**: `GitHub Actions / Jenkins → ECR → EKS`

> Amazon SQS는 VPC 내부 서브넷에 배치되는 서비스가 아니라 AWS의 관리형 서비스이며, 필요 시 VPC Endpoint를 통해 Private Network에서 접근하도록 구성할 수 있습니다.

---

## 👨‍💻 담당 역할과 협업

### AWS Infrastructure

- VPC와 Public / Application Private / DB / Cache Subnet 구성
- NAT Gateway, Route Table, Security Group 구성
- Amazon EKS Cluster 및 Managed Node Group 구축
- AWS Load Balancer Controller 및 EKS Add-on 구성
- Amazon RDS for MariaDB, Amazon ElastiCache for Redis 구성
- Amazon S3 + CloudFront + AWS WAF 기반 웹 서비스 경로 구성
- Amazon SQS + DLQ 기반 AI 작업 비동기 처리 인프라 구성
- Amazon ECR Repository 및 이미지 수명주기 정책 구성

### IAM / Security

- EKS Pod Identity를 이용해 API Pod와 Worker Pod의 IAM 권한 분리
- API Pod에는 SQS `SendMessage` 중심의 최소 권한 부여
- Worker Pod에는 SQS Consume 및 Bedrock Invoke 권한 부여
- External Secrets 연동을 위한 Secrets Manager 조회 권한 구성
- GitHub Actions OIDC 기반 ECR Push Role 구성
- Bastion / AWS Systems Manager 기반 Jenkins 관리 경로 구성

### Infrastructure as Code

- Terraform으로 주요 AWS 인프라를 코드화
- 기존 AWS 리소스와 Terraform State를 맞추기 위한 `terraform import` 작업 수행
- RDS / Redis 고가용성 전환을 위한 별도 마이그레이션 리소스 구성

### 협업

- Backend 담당자와 RDS, Redis, SQS, Bedrock 연결 방식 협의
- Frontend 담당자와 CloudFront 및 API 요청 경로 협의
- ECR / EKS 배포에 필요한 IAM 및 실행 환경 구성
- 실제 서비스 요청이 Frontend → Backend → Data / AI 영역까지 연결되는 흐름 검증

---

## 🧱 Infrastructure Design Points

### 1. 정적 콘텐츠와 API 트래픽 분리

프론트엔드 정적 파일은 Amazon S3에 저장하고 CloudFront를 통해 제공하도록 구성했습니다.

API 요청은 `/api/*` Behavior를 별도로 두어 정적 콘텐츠와 Backend 트래픽의 처리 경로를 분리했습니다.

```text
Static Content
User → CloudFront → S3

API Request
User → CloudFront → VPC Origin → Internal ALB → EKS
```

### 2. CloudFront VPC Origin을 이용한 Backend 노출 범위 축소

초기 Public ALB 중심 구조에서 Backend의 직접 노출 범위를 줄이기 위해 **CloudFront VPC Origin → Internal ALB** 구조를 적용할 수 있도록 구성했습니다.

이를 통해 외부 사용자는 CloudFront를 통해 서비스에 접근하고, Backend Load Balancer는 VPC 내부에서 동작하도록 분리했습니다.

### 3. AI 요청 비동기 처리

AI 일정 생성은 일반 API 요청보다 처리 시간이 길기 때문에 API Pod가 직접 전체 작업을 수행하지 않고 SQS에 작업을 전달하도록 구성했습니다.

```text
Client
  ↓
API Pod
  ↓
Amazon SQS
  ↓
Worker Pod
  ↓
Amazon Bedrock
```

Worker가 큐에서 메시지를 소비하여 Bedrock을 호출하며, 정상 처리되지 못한 메시지는 DLQ로 이동할 수 있도록 구성했습니다.

이를 통해 일반 API 요청과 AI 처리 작업을 분리했습니다.

### 4. Pod 단위 최소 권한

EKS Node에 애플리케이션 권한을 집중시키지 않고 **EKS Pod Identity**를 이용하여 API Pod와 Worker Pod의 IAM Role을 분리했습니다.

- API Pod: SQS 메시지 전송
- Worker Pod: SQS 메시지 소비 + Bedrock 호출

각 Pod에 필요한 권한만 부여하는 방식으로 최소 권한 원칙을 적용했습니다.

### 5. 데이터 계층 분리 및 고가용성 고려

RDS와 Redis를 Private Network 영역에 배치하고 DB / Cache용 Subnet을 분리했습니다.

또한 Redis의 Multi-AZ Replication Group 전환과 RDS의 암호화 Snapshot 기반 마이그레이션을 고려한 Terraform 리소스를 별도로 구성했습니다.

---

## 🛠 Tech Stack

| 영역 | 사용 기술 |
|---|---|
| Cloud | AWS |
| IaC | Terraform |
| Network | VPC, Subnet, NAT Gateway, Route Table, Security Group, VPC Endpoint |
| Container | Docker, Kubernetes, Amazon EKS |
| Traffic | CloudFront, VPC Origin, ALB, AWS WAF |
| Storage | Amazon S3 |
| Database | Amazon RDS for MariaDB |
| Cache | Amazon ElastiCache for Redis |
| Messaging | Amazon SQS, DLQ |
| AI | Amazon Bedrock |
| Registry | Amazon ECR |
| Identity | IAM, EKS Pod Identity, GitHub Actions OIDC |
| CI/CD | Jenkins, GitHub Actions |
| Secret Management | AWS Secrets Manager, SSM Parameter Store, External Secrets 연동용 IAM |

---

## 📁 Repository Structure

```text
TripBuddy-Infrastructure/
├── README.md
├── SECURITY.md
├── .gitignore
│
├── terraform/
│   ├── vpc.tf
│   ├── security_group.tf
│   ├── eks.tf
│   ├── eks_addons.tf
│   ├── eks_access.tf
│   ├── pod_identity.tf
│   ├── alb_controller_iam.tf
│   ├── rds.tf
│   ├── rds_migration.tf
│   ├── elasticache.tf
│   ├── sqs.tf
│   ├── s3.tf
│   ├── cloudfront.tf
│   ├── cloudfront_vpc_origin.tf
│   ├── waf.tf
│   ├── ecr.tf
│   ├── github_actions.tf
│   ├── jenkins.tf
│   ├── bastion.tf
│   ├── secrets.tf
│   ├── variables.tf
│   └── terraform.tfvars.example
│
├── kubernetes/
│   ├── backend-k8s.example.yaml
│   ├── external-secret.example.yaml
│   └── cronjob.example.yaml
│
├── ci/
│   └── Jenkinsfile.example
│
└── docs/
    ├── images/
    │   └── architecture.png
    ├── jenkins-bootstrap.md
    └── bastion-jenkins.md
```

---

## ⚙️ Terraform

AWS 리소스를 콘솔에서 개별적으로 생성하는 방식에만 의존하지 않고 주요 인프라를 Terraform 코드로 관리했습니다.

### 실행 예시

```bash
cd terraform

cp terraform.tfvars.example terraform.tfvars

terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

`terraform.tfvars`에는 AWS Account ID, 관리자 IP CIDR, S3 Bucket 이름, 환경별 ALB 식별자 등의 값을 입력하며 Git에는 커밋하지 않도록 구성했습니다.

> 이 저장소는 포트폴리오용 공개 사본입니다. 실제 환경에 `terraform apply`를 수행하기 전에는 리소스 비용, Provider / Add-on 버전 및 환경별 변수를 반드시 검토해야 합니다.

---

## 🔄 CI/CD

### GitHub Actions OIDC

GitHub에 장기 AWS Access Key를 저장하지 않고 OIDC를 통해 AWS IAM Role을 Assume한 뒤 ECR에 접근할 수 있도록 구성했습니다.

허용 GitHub Repository 정보는 Terraform 변수로 관리하도록 공개본을 정리했습니다.

### Jenkins

Jenkins는 Private Subnet의 EC2에서 운영하고 관리자 접근은 Bastion 또는 AWS Systems Manager를 통해 수행할 수 있도록 구성했습니다.

Jenkins EC2에는 IAM Instance Profile을 부여하여 별도의 장기 AWS Access Key 없이 ECR에 접근할 수 있도록 구성했습니다.

```text
Git Push
   ↓
Jenkins / GitHub Actions
   ↓
Build / Test
   ↓
Docker Image Build
   ↓
Amazon ECR
   ↓
Amazon EKS
```

공개 예제의 Jenkinsfile은 Docker Image Build 및 ECR Push 흐름을 확인할 수 있도록 정리했습니다.

자세한 Jenkins 환경 구성은 [`docs/jenkins-bootstrap.md`](docs/jenkins-bootstrap.md)를 참고할 수 있습니다.

---

## 🔧 Troubleshooting

### 1. Terraform `EntityAlreadyExists`

**문제**

AWS에 기존 IAM Instance Profile이 존재했지만 Terraform State에는 등록되어 있지 않아 동일한 리소스를 새로 생성하려고 하면서 `EntityAlreadyExists` 오류가 발생했습니다.

**원인**

실제 AWS 리소스 상태와 Terraform State가 일치하지 않았습니다.

**해결**

기존 리소스를 삭제하지 않고 `terraform import`를 이용하여 Terraform State에 등록한 뒤 다시 `terraform plan`을 수행했습니다.

**결과 / 배운 점**

Terraform에서는 코드뿐 아니라 **실제 AWS 리소스와 State의 정합성 관리가 중요하다**는 점을 경험했습니다.

---

### 2. EC2 `InvalidKeyPair.NotFound`

**문제**

EC2 생성 과정에서 `InvalidKeyPair.NotFound` 오류가 발생했습니다.

**원인**

Terraform에 지정한 Key Pair 이름과 해당 AWS Region에 실제 존재하는 Key Pair가 일치하지 않았습니다.

**해결**

Key Pair 이름을 환경 변수(`ec2_key_name`)로 분리하고 실제 대상 Region에 존재하는 Key Pair를 확인한 뒤 적용했습니다.

PEM 파일은 Repository 또는 Bastion 서버에 저장하지 않고 관리자 로컬 환경에서만 관리했습니다.

**결과 / 배운 점**

EC2와 같이 Region에 종속되는 리소스는 Terraform 변수뿐 아니라 **실제 배포 대상 Region의 리소스 존재 여부까지 함께 확인해야 한다**는 점을 경험했습니다.

---

### 3. 관리자 CIDR 제한

**문제**

관리용 포트를 광범위한 CIDR에 노출할 경우 불필요한 외부 접근이 가능해질 수 있었습니다.

**해결**

`admin_cidr` 변수에 Validation을 추가하여 `0.0.0.0/0` 사용을 제한하고 관리자 공인 IP `/32`만 입력하도록 구성했습니다.

```hcl
validation {
  condition     = can(cidrhost(var.admin_cidr, 0)) && var.admin_cidr != "0.0.0.0/0"
  error_message = "admin_cidr must be a valid CIDR and must not be 0.0.0.0/0."
}
```

**결과 / 배운 점**

인프라 코드를 작성할 때 리소스 생성뿐 아니라 잘못된 설정이 입력되는 것을 사전에 막는 **Validation의 중요성**을 경험했습니다.

---

### 4. Public ALB → CloudFront VPC Origin 전환

**문제**

CloudFront가 Public ALB를 Origin으로 사용하는 구조에서는 Backend Load Balancer가 외부에 직접 노출되는 구조가 됩니다.

**개선**

Backend 노출 범위를 줄이기 위해 CloudFront VPC Origin에서 Internal ALB로 연결되는 구조를 구성했습니다.

```text
Before
User → CloudFront → Public ALB → EKS

After
User → CloudFront → VPC Origin → Internal ALB → EKS
```

**결과 / 배운 점**

서비스가 정상 동작하는 것뿐 아니라 **외부에 노출해야 하는 영역과 내부에 유지해야 하는 영역을 구분하는 네트워크 설계가 중요하다**는 점을 경험했습니다.

---

## ✅ 구축 및 동작 검증

인프라 리소스를 생성하는 것에서 끝내지 않고 실제 서비스 요청 흐름을 기준으로 연결 상태를 확인했습니다.

- CloudFront를 통한 Frontend 정적 콘텐츠 접근 확인
- `/api/*` 요청의 Backend 전달 경로 확인
- ALB → EKS Backend 연결 확인
- Backend → RDS 연결 및 데이터 저장 흐름 확인
- Backend → Redis 연결 확인
- API → SQS 메시지 전달 흐름 확인
- SQS → Worker 비동기 처리 흐름 확인
- Worker → Amazon Bedrock 호출 경로 확인
- ECR에 저장된 Container Image를 EKS Workload에서 사용하는 배포 흐름 확인

Terraform 변경 시에는 바로 `apply`하기보다 먼저 `terraform plan`을 확인하여 기존 AWS 리소스가 의도치 않게 변경 또는 교체되지 않는지 검토하는 방식으로 작업했습니다.

---

## 🔐 공개 저장소 보안 처리

이 저장소는 실제 개발 환경에서 사용한 인프라 코드를 포트폴리오용으로 정리한 공개 사본입니다.

다음 정보는 제거하거나 Example / Terraform Variable 형태로 변경했습니다.

- RDS / Redis 실제 Endpoint
- DB Password / JWT Secret / 외부 API Key
- AWS Account ID
- ECR Registry Account ID
- 팀원 IAM User ARN
- 외부 Backup DB IP 및 계정 정보
- 환경별 ALB ARN / DNS
- Terraform State 및 `terraform.tfvars`
- PEM / Private Key

Kubernetes Secret 값은 Repository에 직접 저장하지 않고 Secret Management Workflow로 주입하는 예제를 남겼습니다.

자세한 공개 저장소 보안 원칙은 [`SECURITY.md`](SECURITY.md)를 참고할 수 있습니다.

---

## 📝 프로젝트를 통해 배운 점

TripBuddy 인프라를 구축하면서 개별 AWS 서비스를 생성하는 것보다 **사용자 요청이 어떤 경로를 거쳐 애플리케이션, 데이터베이스, 메시지 큐, AI 서비스까지 연결되는지 전체 흐름을 이해하는 것이 중요하다**는 점을 경험했습니다.

또한 Terraform을 사용하면서 실제 AWS 리소스와 State의 정합성, IAM 최소 권한, Private Network에서의 운영 접근, CI/CD에서의 인증 방식, AI처럼 처리 시간이 긴 작업의 비동기 분리 등 실제 서비스 배포 과정에서 필요한 인프라 관점을 익힐 수 있었습니다.

---

## ⚠️ Note

이 저장소는 교육 및 포트폴리오 목적으로 정리한 공개 사본이며 실제 운영 환경의 완전한 복제본은 아닙니다.

환경 고유 정보와 민감정보는 제거하거나 예시값 또는 Terraform 변수로 치환했습니다.
