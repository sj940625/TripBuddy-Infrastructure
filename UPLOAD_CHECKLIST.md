# GitHub 업로드 체크리스트

1. GitHub에서 새 Public Repository를 만듭니다. 추천 이름: `TripBuddy-Infrastructure`.
2. 이 폴더의 **내용물 전체**를 저장소 루트에 올립니다. ZIP 파일 자체를 커밋하지 않습니다.
3. 업로드 전에 `terraform/terraform.tfvars`가 없는지 확인합니다. 이 저장소에는 예제 파일만 포함되어 있습니다.
4. `*.tfstate`, `.terraform/`, `.env`, `*.pem`, 실제 Secret YAML이 커밋되지 않았는지 확인합니다.
5. GitHub의 README 미리보기에서 Mermaid 아키텍처가 정상 표시되는지 확인합니다.
6. 저장소 About 설명 예시: `TripBuddy AWS Infrastructure & DevOps Portfolio - Terraform, EKS, CloudFront, SQS, RDS, Redis`
7. Topics 예시: `aws`, `terraform`, `eks`, `kubernetes`, `devops`, `cloudfront`, `sqs`, `rds`, `redis`

> 실제 자격 증명이 과거 Git 기록에 들어간 적이 있다면 파일 삭제만 하지 말고 해당 자격 증명을 폐기/회전해야 합니다.
