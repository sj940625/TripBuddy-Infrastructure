# Jenkins CI bootstrap

`terraform/`의 Terraform 전체를 일반 `terraform apply` 하면 EKS/RDS/ElastiCache/NAT 2개 등도 함께 생성됩니다.
Jenkins CI만 먼저 검증하려면 아래 순서로 진행합니다.

## 1) AWS 계정 확인

```bash
aws sts get-caller-identity --query Account --output text
```

반드시 아래 값이 나와야 합니다.

```text
<AWS_ACCOUNT_ID>
```

`provider.tf`에도 `allowed_account_ids`를 넣어 잘못된 AWS 계정에 Apply되는 것을 막았습니다.

## 2) Terraform 초기화/검증

```bash
terraform init
terraform fmt -recursive
terraform validate
```

## 3) Jenkins EC2 부트스트랩 Plan

```bash
terraform plan -target=aws_instance.jenkins -out=jenkins.tfplan
```

이 Target 방식은 현재 프로젝트의 전체 EKS/RDS 등을 한 번에 만들지 않고 Jenkins CI를 먼저 검증하기 위한 임시 부트스트랩 용도입니다.

## 4) Apply

```bash
terraform apply jenkins.tfplan
```

## 5) Instance ID 확인

```bash
terraform output jenkins_instance_id
```

## 6) Private Jenkins 접속

로컬 PC에 AWS Session Manager Plugin이 준비되어 있다면:

```bash
aws ssm start-session \
  --target $(terraform output -raw jenkins_instance_id) \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}'
```

그 후 브라우저에서 `http://localhost:8080` 접속.

초기 비밀번호 확인:

```bash
aws ssm start-session --target $(terraform output -raw jenkins_instance_id)
```

EC2 세션 안에서:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## 7) CI

`ci/Jenkinsfile.example`을 애플리케이션 저장소의 `Jenkinsfile`로 옮겨 사용합니다.
Dockerfile이 저장소 루트에 있어야 현재 예제가 그대로 동작합니다.

Jenkins EC2는 IAM Role로 ECR Push 권한을 받으므로 Access Key/Secret Key를 Jenkins에 직접 저장하지 않아도 됩니다.

## GitLab Webhook 주의

Private Subnet Jenkins는 NAT Gateway를 통해 **밖으로 나갈 수는 있지만**, GitLab.com에서 NAT Gateway를 통해 Jenkins로 **들어올 수는 없습니다**.

따라서 GitLab SaaS Webhook까지 쓰려면 추후 Public ALB -> Private Jenkins 형태의 inbound 경로를 추가하거나, 우선 Jenkins의 SCM Polling/수동 빌드로 CI를 검증합니다.
